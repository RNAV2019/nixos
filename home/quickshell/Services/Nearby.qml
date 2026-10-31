pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The nearbyd link: one long-lived `nearby events` subscription carries every change, and
// each control is one short-lived `nearby` call. Events are the source of truth - the
// daemon repeats state, peers and transfers on the stream - so an action's reply is never
// what the panel draws. See ~/Projects/nearby/docs/protocol.md.
Singleton {
  id: root

  // The last `status` event, verbatim; the readable roles are derived below.
  property var status: ({})

  // Peers and transfers as plain arrays, re-assigned wholesale on every change so QML
  // bindings see them (Bus's writeMap pattern).
  property var peers: []
  property var transfers: []

  // True while the event stream is up. When it drops, the reconnect timer keeps trying,
  // which is how the panel notices a nearbyd restart.
  property bool connected: false

  readonly property string mode: status.mode !== undefined ? status.mode : "android"
  readonly property bool scanning: status.scanning === true
  readonly property bool busy: status.busy === true
  readonly property bool receivable: status.visible === true
  readonly property bool hasRemaining: status.remaining !== undefined && status.remaining !== null
  readonly property int remaining: hasRemaining ? status.remaining : 0
  readonly property string deviceName: status.name !== undefined ? status.name : ""
  readonly property string downloadDir: status.download_dir !== undefined ? status.download_dir : ""
  readonly property var android: status.android !== undefined ? status.android : ({})
  readonly property var apple: status.apple !== undefined ? status.apple : ({})

  // Apple mode runs the AWDL radio in omdrop's exclusive mode: on Intel cards Wi-Fi is
  // down for as long as the window (or a send) runs, which the panel tints in gold.
  readonly property bool wifiPaused: mode === "apple"

  // The visibility window as m:ss, or empty while it runs until told otherwise.
  readonly property string remainingLabel: {
    if (!root.hasRemaining)
      return "";
    var s = Math.max(0, root.remaining);
    var m = Math.floor(s / 60);
    var r = s % 60;
    return m + ":" + (r < 10 ? "0" : "") + r;
  }

  // Inbound Quick Share offers waiting for an answer; AirDrop accepts itself in omdrop.
  // Strict match on the daemon's exact states: anything else (e.g. a transient
  // "connecting" that has not yet become consent) is exposed via inboundConnecting
  // below so the panel can hint instead of silently hiding it.
  readonly property var pendingInbound: root.transfers.filter(function (t) {
    return t.direction === "in" && t.state === "waiting_consent";
  })

  // Inbound rows that exist but are not yet answerable (usually "connecting").
  // Sorted newest first; the panel shows a "Connecting…" hint rather than nothing.
  readonly property var inboundConnecting: root.transfers.filter(function (t) {
    return t.direction === "in" && t.state === "connecting";
  }).slice().sort(function (a, b) {
    return (b.started || 0) - (a.started || 0);
  })

  // Finished arrivals, newest first. AirDrop inbounds are synthesised finished already.
  readonly property var received: root.transfers.filter(function (t) {
    return t.direction === "in" && t.state === "finished";
  }).slice().sort(function (a, b) {
    return (b.started || 0) - (a.started || 0);
  })

  // The panel's arrival list: anything inbound that has passed consent, receiving or done,
  // newest first, so an in-flight transfer shows its progress bar in place.
  readonly property var receivedList: root.transfers.filter(function (t) {
    return t.direction === "in" && (t.state === "in_progress" || t.state === "finished");
  }).slice().sort(function (a, b) {
    return (b.started || 0) - (a.started || 0);
  })

  // ---- file kinds and sizes, shared by the staged rows, the picker and the arrivals ----

  function baseName(path) {
    var s = String(path);
    while (s.length > 1 && s.charAt(s.length - 1) === "/")
      s = s.substring(0, s.length - 1);
    return s.split("/").pop();
  }

  function extOf(name) {
    var n = baseName(name);
    var dot = n.lastIndexOf(".");
    return dot > 0 ? n.substring(dot + 1).toLowerCase() : "";
  }

  // "image" | "pdf" | "archive" | "text" | "file"; directories are the caller's to know.
  function fileKind(name) {
    var ext = extOf(name);
    if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "avif", "heic", "heif", "svg", "tif", "tiff"].indexOf(ext) !== -1)
      return "image";
    if (ext === "pdf")
      return "pdf";
    if (["zip", "tar", "gz", "tgz", "xz", "7z", "rar", "bz2", "zst", "apk", "deb", "rpm"].indexOf(ext) !== -1)
      return "archive";
    if (["txt", "md", "nix", "rs", "qml", "js", "ts", "json", "toml", "yaml", "yml", "py", "sh", "fish", "c", "h", "cpp", "go", "lua", "css", "html", "csv", "log", "conf", "ini", "bib", "tex"].indexOf(ext) !== -1)
      return "text";
    return "file";
  }

  // Formats Qt's Image can draw, so a preview is only attempted where it can succeed.
  function isPreviewableImage(name) {
    return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "heic", "heif", "tif", "tiff"].indexOf(extOf(name)) !== -1;
  }

  function glyphFor(kind) {
    switch (kind) {
    case "dir":
      return IconPaths.folder;
    case "image":
      return IconPaths.image;
    case "pdf":
    case "text":
      return IconPaths.fileText;
    case "archive":
      return IconPaths.fileArchive;
    }
    return IconPaths.file;
  }

  // Boards 16b/16c/16e: folders in the accent, PDFs love, images foam, archives gold.
  function inkFor(kind) {
    switch (kind) {
    case "dir":
      return Theme.accentFill;
    case "image":
      return Theme.foam;
    case "pdf":
      return Theme.love;
    case "archive":
      return Theme.gold;
    }
    return Theme.inkSecondary;
  }

  // "214 KB", "2.4 MB", "96 MB": one decimal only where it carries information.
  function sizeLabel(bytes) {
    var b = Number(bytes);
    if (!(b > 0))
      return b === 0 ? "0 B" : "";
    if (b < 1024)
      return b + " B";
    if (b < 1024 * 1024)
      return Math.max(1, Math.round(b / 1024)) + " KB";
    var units = ["MB", "GB", "TB"];
    var v = b / (1024 * 1024);
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    var s = v >= 100 ? String(Math.round(v)) : v.toFixed(1);
    if (s.indexOf(".") !== -1 && s.charAt(s.length - 1) === "0")
      s = s.substring(0, s.length - 2);
    return s + " " + units[i];
  }

  // The first file a transfer names, for rows and pills: where it was saved, else what was offered.
  function transferName(t) {
    if (!t)
      return "";
    var paths = t.saved_paths || [];
    if (paths.length > 0)
      return baseName(paths[0]);
    var files = t.files || [];
    if (files.length > 0)
      return baseName(files[0]);
    return t.text ? t.text : "file";
  }

  // "IMG_2041.jpg +2 · 6.1 MB", the payload line of a consent card or the pill's request.
  function payloadLabel(t) {
    if (!t)
      return "";
    var files = t.files || [];
    var head = t.kind !== "files" && t.text ? t.text : (files.length > 0 ? baseName(files[0]) : "files");
    if (files.length > 1)
      head += " +" + (files.length - 1);
    var size = t.total_bytes > 0 ? sizeLabel(t.total_bytes) : "";
    return size !== "" ? head + " · " + size : head;
  }

  // 0..1 for a row's background bar; a finished transfer is full.
  function progressOf(t) {
    if (!t)
      return 0;
    if (t.state === "finished")
      return 1;
    if (!t.total_bytes || t.total_bytes <= 0)
      return 0;
    return Theme.clamp01((t.bytes || 0) / t.total_bytes);
  }

  function isTerminalState(s) {
    return s === "finished" || s === "rejected" || s === "cancelled" || s === "failed";
  }

  // The newest arrival, for the accent ground it wears for a few seconds (board 16h).
  property string lastArrival: ""
  property string freshArrival: ""

  onLastArrivalChanged: {
    freshArrival = lastArrival;
    if (lastArrival !== "")
      arrivalGlow.restart();
  }

  Timer {
    id: arrivalGlow

    interval: Theme.nearbyArrivalGlow
    onTriggered: root.freshArrival = ""
  }

  // Peers of the stack the panel is showing: Quick Share in Android mode, AirDrop in Apple.
  readonly property var peersForMode: root.peers.filter(function (p) {
    return p.protocol === (root.mode === "apple" ? "airdrop" : "quickshare");
  })

  // An AirDrop transfer still running, which holds the Apple window (and the Wi-Fi) open.
  readonly property bool appleTransferActive: root.transfers.some(function (t) {
    return t.protocol === "airdrop" && !root.isTerminalState(t.state);
  })

  function peerById(id) {
    for (var i = 0; i < peers.length; i++) {
      if (peers[i].id === id)
        return peers[i];
    }
    return null;
  }

  function transferById(id) {
    for (var i = 0; i < transfers.length; i++) {
      if (transfers[i].id === id)
        return transfers[i];
    }
    return null;
  }

  // Every outbound id known right now; a fresh staging ignores them all, so a finished send
  // from an earlier round cannot light a tile.
  function outboundIds() {
    var out = [];
    for (var i = 0; i < transfers.length; i++) {
      if (transfers[i].direction === "out")
        out.push(transfers[i].id);
    }
    return out;
  }

  // True while a send outside `ignoreIds` is still running.
  function outboundInFlight(ignoreIds) {
    for (var i = 0; i < transfers.length; i++) {
      var t = transfers[i];
      if (t.direction === "out" && !isTerminalState(t.state) && (!ignoreIds || ignoreIds.indexOf(t.id) === -1))
        return true;
    }
    return false;
  }

  // The latest daemon notice, shown in the panel so a failure is not silent.
  property string noticeText: ""
  property string noticeLevel: ""

  signal notice(string level, string message)

  Timer {
    id: noticeClear

    interval: 6000
    onTriggered: {
      root.noticeText = "";
      root.noticeLevel = "";
    }
  }

  function showNotice(level, message) {
    if (!message)
      return;
    root.noticeLevel = level;
    root.noticeText = message;
    noticeClear.restart();
    root.notice(level, message);
  }

  // Raised when something asks the panel to open in Send mode with a set of files - a drop
  // on the island adds them at once.
  signal sendRequested(var files)

  // Raised to open the panel on the receive view.
  signal receiveRequested

  // Direct open bypassing the Bus.focused gate: the panel listens and calls
  // win.show() itself on its focused output. Bus.toggleSurface is still tried
  // for handoff bookkeeping, but an IPC while unfocused no longer silent-drops.
  signal forceOpen

  function requestSend(files) {
    sendRequested(files);
    forceOpen();
    // The island asks while no panel is up; a second ask with one already open just
    // updates its staged files.
    if (Bus.ownerOf("nearby") === "")
      Bus.toggleSurface("nearby");
  }

  function requestReceive() {
    receiveRequested();
    forceOpen();
    if (Bus.ownerOf("nearby") === "")
      Bus.toggleSurface("nearby");
  }

  // Drag payloads arrive as file:// urls; nearby wants real paths.
  function pathFromUrl(url) {
    var s = String(url);
    if (s.indexOf("file://") === 0)
      s = s.substring(7);
    return decodeURIComponent(s);
  }

  function pathsFromUrls(urls) {
    var out = [];
    for (var i = 0; i < urls.length; i++)
      out.push(pathFromUrl(urls[i]));
    return out;
  }

  // ---- state from the event stream ----

  function applyEvent(ev) {
    if (!ev || !ev.event)
      return;
    switch (ev.event) {
    case "status":
      root.status = ev.status !== undefined ? ev.status : {};
      break;
    case "peer":
      upsertPeer(ev.peer);
      break;
    case "peer_lost":
      removePeer(ev.id);
      break;
    case "transfer":
      upsertTransfer(ev.transfer);
      break;
    case "notice":
      root.showNotice(ev.level !== undefined ? ev.level : "info", ev.message !== undefined ? ev.message : "");
      break;
    case "transfers_cleared":
      // The daemon keeps anything still running; drop the same set here so a reconnect
      // does not resurrect what the panel just cleared.
      root.transfers = root.transfers.filter(function (t) {
        return !root.isTerminalState(t.state);
      });
      break;
    }
  }

  function upsertPeer(peer) {
    if (!peer || !peer.id)
      return;
    var next = [];
    var seen = false;
    for (var i = 0; i < peers.length; i++) {
      if (peers[i].id === peer.id) {
        next.push(peer);
        seen = true;
      } else {
        next.push(peers[i]);
      }
    }
    if (!seen)
      next.push(peer);
    peers = next;
  }

  function removePeer(id) {
    if (!id)
      return;
    var next = [];
    for (var i = 0; i < peers.length; i++) {
      if (peers[i].id !== id)
        next.push(peers[i]);
    }
    peers = next;
  }

  // Transfer events repeat for one id as state and byte counts move; the newest replaces
  // the row. An inbound arriving finished wants its entrance glow.
  // A consent becoming answerable surfaces itself: rows now exist from the
  // handshake on ("connecting"), so this fires on the transition into
  // waiting_consent, not just on brand-new ids. If the panel is already open
  // but sitting in Send, flip it to Receive so the card is seen. When the
  // panel is shut the SharingPill owns the prompt (it has shown a
  // "Connecting…" hint since the handshake started).
  function upsertTransfer(t) {
    if (!t || !t.id)
      return;
    var wasAnswerable = false;
    for (var k = 0; k < transfers.length; k++) {
      if (transfers[k].id === t.id) {
        wasAnswerable = transfers[k].state === "waiting_consent";
        break;
      }
    }
    var isNewConsent = t.direction === "in" && t.state === "waiting_consent" && !wasAnswerable;
    var next = [];
    var seen = false;
    for (var i = 0; i < transfers.length; i++) {
      if (transfers[i].id === t.id) {
        if (t.direction === "in" && t.state === "finished" && transfers[i].state !== "finished")
          root.lastArrival = t.id;
        next.push(t);
        seen = true;
      } else {
        next.push(transfers[i]);
      }
    }
    if (!seen) {
      next.push(t);
      if (t.direction === "in" && t.state === "finished")
        root.lastArrival = t.id;
    }
    transfers = next.slice(-50);
    if (isNewConsent) {
      // If the nearby panel is shut, the SharingPill owns the prompt. If it
      // is already open but sitting in Send, flip it to Receive.
      if (Bus.ownerOf("nearby") !== "")
        receiveRequested();
    }
  }

  // The live outbound row for a device tile, matched on the name the daemon recorded. Ids in
  // `ignoreIds` belong to a previous staging and are skipped.
  function outgoingFor(peer, ignoreIds) {
    if (!peer)
      return null;
    var found = null;
    for (var i = 0; i < transfers.length; i++) {
      var t = transfers[i];
      if (t.direction !== "out")
        continue;
      if (ignoreIds && ignoreIds.indexOf(t.id) !== -1)
        continue;
      if (t.peer !== peer.name && t.peer !== peer.id && t.id !== peer.id)
        continue;
      if (!found || (t.started || 0) >= (found.started || 0))
        found = t;
    }
    return found;
  }

  // ---- actions: one `nearby` call each ----

  function setMode(m) {
    modeCall.command = ["nearby", "mode", m];
    modeCall.errText = "";
    modeCall.running = true;
  }

  function turnOn() {
    windowCall.command = ["nearby", "on"];
    windowCall.errText = "";
    windowCall.running = true;
  }

  // Visible until turned off (the daemon's `on 0`): receive mode should not expire out from
  // under a phone whose own "Everyone" window has already reverted to Contacts.
  function turnOnForever() {
    windowCall.command = ["nearby", "on", "forever"];
    windowCall.errText = "";
    windowCall.running = true;
  }

  function turnOff() {
    windowCall.command = ["nearby", "off"];
    windowCall.errText = "";
    windowCall.running = true;
  }

  // Peer ids live for one scan only, so the send view keeps a scan running while it is up.
  function scanOn(seconds) {
    scanCall.command = ["nearby", "scan", "on", "--for", String(seconds !== undefined ? seconds : 20)];
    scanCall.errText = "";
    scanCall.running = true;
  }

  function scanOff() {
    scanCall.command = ["nearby", "scan", "off"];
    scanCall.errText = "";
    scanCall.running = true;
  }

  function send(files, peerRef) {
    if (!files || files.length === 0 || !peerRef)
      return;
    sendCall.command = ["nearby", "send", "--detach"].concat(files).concat(["--to", peerRef]);
    sendCall.errText = "";
    sendCall.running = true;
  }

  // Forget the finished/declined/cancelled rows so the received list does not grow forever.
  function clearReceived() {
    clearCall.command = ["nearby", "clear"];
    clearCall.errText = "";
    clearCall.running = true;
  }

  function accept(id) {
    acceptCall.command = ["nearby", "accept", id];
    acceptCall.errText = "";
    acceptCall.running = true;
  }

  function decline(id) {
    declineCall.command = ["nearby", "decline", id];
    declineCall.errText = "";
    declineCall.running = true;
  }

  function cancel(id) {
    cancelCall.command = ["nearby", "cancel", id];
    cancelCall.errText = "";
    cancelCall.running = true;
  }

  function openDownloads() {
    if (downloadDir !== "")
      Launch.open(downloadDir);
  }

  function openFile(path) {
    if (path)
      Launch.open(path);
  }

  // ---- plumbing ----

  // Errors come back as the daemon's notice events and as a failed transfer row; a call
  // that exits non-zero says so the same way.
  function fail(proc, what, code) {
    proc.exitCode = code;
    if (code === 0)
      return;
    var text = proc.errText !== undefined ? proc.errText : "";
    root.showNotice("error", what + (text !== "" ? ": " + text : ""));
  }

  Process {
    id: events

    command: ["nearby", "events"]
    running: true

    stdout: SplitParser {
      onRead: function (line) {
        var text = line.trim();
        if (text === "")
          return;
        try {
          root.applyEvent(JSON.parse(text));
        } catch (e) {
          console.warn("nearby events: dropping unparsable line: " + text);
        }
      }
    }

    onRunningChanged: {
      root.connected = events.running;
      // Fresh subscribe replays status+peers+transfers from the daemon, which
      // heals any gap while the stream was down (restart, Lagged drop).
      if (events.running)
        resyncCall.running = true;
    }

    // nearbyd restarted, or was not up yet: reconnect.
    onExited: restart.start()
  }

  // One-shot snapshot merge after (re)connect: the daemon's subscribe already
  // replays, but an explicit transfers dump covers a Lagged Status-only repair.
  Command {
    id: resyncCall

    logFailures: false

    command: ["nearby", "transfers", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var arr = JSON.parse(text);
          if (Array.isArray(arr)) {
            for (var i = 0; i < arr.length; i++)
              root.upsertTransfer(arr[i]);
          }
        } catch (e) {
          console.warn("nearby resync: dropping unparsable transfers dump");
        }
      }
    }
    onExited: function (code) {
      if (code !== 0)
        console.warn("nearby resync failed (" + code + "): " + resyncCall.errText);
    }
  }

  Timer {
    id: restart

    interval: 2000
    onTriggered: events.running = true
  }

  Command {
    id: modeCall

    onExited: function (code) {
      root.fail(modeCall, "Mode switch", code);
    }
  }

  Command {
    id: windowCall

    onExited: function (code) {
      root.fail(windowCall, "Visibility", code);
    }
  }

  Command {
    id: scanCall

    onExited: function (code) {
      root.fail(scanCall, "Scan", code);
    }
  }

  Command {
    id: sendCall

    onExited: function (code) {
      root.fail(sendCall, "Send", code);
    }
  }

  Command {
    id: acceptCall

    onExited: function (code) {
      root.fail(acceptCall, "Accept", code);
    }
  }

  Command {
    id: declineCall

    onExited: function (code) {
      root.fail(declineCall, "Decline", code);
    }
  }

  Command {
    id: cancelCall

    onExited: function (code) {
      root.fail(cancelCall, "Cancel", code);
    }
  }

  Command {
    id: clearCall

    onExited: function (code) {
      root.fail(clearCall, "Clear", code);
    }
  }
}
