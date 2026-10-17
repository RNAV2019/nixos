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
  readonly property var pendingInbound: root.transfers.filter(function (t) {
    return t.direction === "in" && t.state === "waiting_consent";
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

  // The newest row to arrive while the panel has been up, for its 4 s accent edge.
  property string lastArrival: ""

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

  function requestSend(files) {
    sendRequested(files);
    // The island asks while no panel is up; a second ask with one already open just
    // updates its staged files.
    if (Bus.ownerOf("nearby") === "")
      Bus.toggleSurface("nearby");
  }

  function requestReceive() {
    receiveRequested();
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
  function upsertTransfer(t) {
    if (!t || !t.id)
      return;
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
  }

  // Finished/failed sends known right now; a panel snapshots these when it stages files so a
  // completed send from an earlier round cannot light a tile before this round is sent. Sends
  // still in flight are deliberately left out, so their progress keeps showing if more files
  // are added mid-send.
  function terminalOutboundIds() {
    var out = [];
    for (var i = 0; i < transfers.length; i++) {
      var t = transfers[i];
      if (t.direction === "out" && root.isTerminalState(t.state))
        out.push(t.id);
    }
    return out;
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
    answerCall.command = ["nearby", "accept", id];
    answerCall.errText = "";
    answerCall.running = true;
  }

  function decline(id) {
    answerCall.command = ["nearby", "decline", id];
    answerCall.errText = "";
    answerCall.running = true;
  }

  function cancel(id) {
    answerCall.command = ["nearby", "cancel", id];
    answerCall.errText = "";
    answerCall.running = true;
  }

  function openDownloads() {
    if (downloadDir !== "")
      Quickshell.execDetached(["xdg-open", downloadDir]);
  }

  function openFile(path) {
    if (path)
      Quickshell.execDetached(["xdg-open", path]);
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
          // A partial line cannot happen over the pipe, but a stray write might.
        }
      }
    }

    onRunningChanged: root.connected = events.running

    // nearbyd restarted, or was not up yet: reconnect.
    onExited: restart.start()
  }

  Timer {
    id: restart

    interval: 2000
    onTriggered: events.running = true
  }

  component Call: Process {
    id: call

    property string errText: ""
    property int exitCode: 0

    stderr: StdioCollector {
      onStreamFinished: call.errText = text.trim()
    }
  }

  Call {
    id: modeCall

    onExited: function (code) {
      root.fail(modeCall, "Mode switch", code);
    }
  }

  Call {
    id: windowCall

    onExited: function (code) {
      root.fail(windowCall, "Visibility", code);
    }
  }

  Call {
    id: scanCall

    onExited: function (code) {
      root.fail(scanCall, "Scan", code);
    }
  }

  Call {
    id: sendCall

    onExited: function (code) {
      root.fail(sendCall, "Send", code);
    }
  }

  Call {
    id: answerCall

    onExited: function (code) {
      root.fail(answerCall, "Answer", code);
    }
  }

  Call {
    id: clearCall

    onExited: function (code) {
      root.fail(clearCall, "Clear", code);
    }
  }
}
