pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The phone, through KDE Connect. Quickshell has no D-Bus client, so `phone-bridge events`
// (pkgs/phone-bridge) watches kdeconnectd on the session bus and prints the whole picture as a
// JSON line whenever it changes: paired devices that are reachable (or asking to pair), each
// with its battery, mobile signal and the notifications it has up. The controls go the other
// way, straight to the daemon with `busctl`, so each is one visible D-Bus call.
//
// The phone is the first paired and reachable smartphone (else tablet). Bar/PhoneSatellite.qml
// buds out of the island while there is one; Phone/PhonePanel.qml is what it opens.
//
// Transfers come from the same process: it serves KDE's job tracker, so kdeconnectd's progress
// for what it sends and receives arrives as `transfer` lines, which Services/Nearby.qml takes
// into its own list. A send that finishes inside the tracker's half-second delay is never
// reported, so a share shows as sending from the call and is taken as done if no job turns up.
//
// What KDE Connect cannot say, the panel does without: the phone's own Wi-Fi is not reported,
// but a LAN link means it shares this machine's network, so that network's name stands in; a
// ring cannot be stopped from here. Text copied on either side reaches the other through KDE
// Connect's own clipboard sync, so there is nothing to send by hand.
Singleton {
  id: root

  // ---- the picture from phone-bridge ----

  property bool daemon: false
  property var devices: []

  // The one shown last stays the phone while it is paired and reachable, so a second device
  // appearing does not take the satellite from it. Chosen when a picture arrives.
  property var phone: null

  // KDE Connect 26.08 calls a phone "phone"; earlier releases said "smartphone".
  function _isPhone(d) {
    return d.type === "phone" || d.type === "smartphone";
  }

  function _pick(devices) {
    var held = root.phone !== null ? root.phone.id : "";
    var pick = null;
    for (var i = 0; i < devices.length; i++) {
      var d = devices[i];
      if (!d.paired || !d.reachable || (!root._isPhone(d) && d.type !== "tablet"))
        continue;
      if (d.id === held)
        return d;
      if (pick === null || (pick.type === "tablet" && root._isPhone(d)))
        pick = d;
    }
    return pick;
  }

  readonly property bool connected: phone !== null
  readonly property string deviceId: phone ? phone.id : ""
  readonly property string name: phone ? phone.name : ""
  // "Wi-Fi" for a LAN link, "Bluetooth", or "".
  readonly property string link: phone ? phone.link : ""
  readonly property bool hasBattery: phone !== null && phone.battery !== null
  readonly property int charge: hasBattery ? phone.battery.charge : -1
  readonly property bool charging: hasBattery && phone.battery.charging
  readonly property bool low: hasBattery && !charging && charge <= Theme.phoneLowBattery

  // "5G", "LTE"... and 0-4 bars, -1 before the phone has reported any.
  readonly property string cellularType: phone && phone.cellular ? phone.cellular.type : ""
  readonly property int cellularStrength: phone && phone.cellular ? phone.cellular.strength : -1

  // The network the phone is on, when the link says it is this machine's.
  readonly property string wifiName: link === "Wi-Fi" && NetworkInfo.activeNetwork ? NetworkInfo.activeNetwork.name : ""

  // The phone's notifications, newest first; only reassigned when one changes, so the panel's
  // rows are not rebuilt by a battery reading.
  property var notifications: []

  // What the bridge says about a transfer (see phone-bridge.py), and a placeholder that a real
  // one replaces.
  signal transferEvent(var transfer)
  signal transferDropped(string id)

  function _transfer(event) {
    var t = event.transfer;
    if (t.direction === "out" && root._pending !== "") {
      root.transferDropped(root._pending);
      root._pending = "";
      pendingDone.stop();
    }
    root.transferEvent(t);
  }

  function _apply(state) {
    root.daemon = state.daemon === true;
    var devices = state.devices || [];
    root.phone = root._pick(devices);
    root.devices = devices;
    var next = root.phone !== null ? root.phone.notifications : [];
    if (JSON.stringify(next) !== JSON.stringify(root.notifications))
      root.notifications = next;
  }

  // ---- the bridge process ----

  // Nothing to show once it is gone; it is started again after a pause that doubles up to a
  // minute, which is also what a shell without phone-bridge on its PATH sees.
  Stream {
    command: ["phone-bridge", "events"]
    retryMs: 5000
    maxRetryMs: 60000

    onLine: function (text) {
      var state;
      try {
        state = JSON.parse(text);
      } catch (err) {
        return;
      }
      if (state.event === "transfer")
        root._transfer(state);
      else
        root._apply(state);
    }

    onConnectedChanged: if (!connected)
      root._apply({})
  }

  // ---- calling kdeconnectd ----

  Command {
    id: ringCall

    label: "Ring phone"
  }

  Command {
    id: shareCall

    label: "Send files to phone"

    onFailed: function (code, message) {
      root._finishPending("failed", message !== "" ? message : "Could not send");
    }
  }

  Command {
    id: cancelCall

    label: "Cancel phone transfer"
  }

  function _call(run, path, iface, member, args) {
    return run.exec(["busctl", "--user", "call", "org.kde.kdeconnect", path, iface, member].concat(args || []));
  }

  function _plugin(name) {
    return "/modules/kdeconnect/devices/" + deviceId + "/" + name;
  }

  // The phone rings until someone picks it up, and nothing here can stop it, so the button
  // only says so for a while.
  property bool ringing: false

  function ring() {
    if (!connected)
      return;
    root._call(ringCall, _plugin("findmyphone"), "org.kde.kdeconnect.device.findmyphone", "ring");
    root.ringing = true;
    ringReset.restart();
  }

  Timer {
    id: ringReset

    interval: 8000
    onTriggered: root.ringing = false
  }

  // The share that has been called and not yet shown by a job, as a transfer of its own.
  property string _pending: ""
  property var _pendingFiles: []
  property int _pendingSerial: 0

  function _pendingRow(state, error) {
    return {
      id: root._pending,
      protocol: "kdeconnect",
      direction: "out",
      state: state,
      peer: root.name,
      kind: "files",
      files: root._pendingFiles,
      saved_paths: [],
      total_bytes: 0,
      bytes: 0,
      percent: state === "finished" ? 100 : null,
      error: error || null,
      started: Date.now() / 1000
    };
  }

  function _finishPending(state, error) {
    if (root._pending === "")
      return;
    root.transferEvent(root._pendingRow(state, error));
    root._pending = "";
    pendingDone.stop();
  }

  // A job that exists is on the tracker half a second after the call; one that is not by
  // then has finished or never started, and the call did not fail.
  Timer {
    id: pendingDone

    interval: 2500
    onTriggered: root._finishPending("finished")
  }

  // Absolute paths; folders are sent as KDE Connect sends them.
  function share(paths) {
    if (!connected || paths.length === 0)
      return;
    var urls = paths.map(function (p) {
      return "file://" + encodeURI(p);
    });
    if (!root._call(shareCall, _plugin("share"), "org.kde.kdeconnect.device.share", "shareUrls", ["as", String(urls.length)].concat(urls)))
      return;
    root._pending = "kdc:pending:" + (++root._pendingSerial);
    root._pendingFiles = paths.map(function (p) {
      return p.split("/").pop();
    });
    root.transferEvent(root._pendingRow("in_progress", ""));
    pendingDone.restart();
  }

  // Asks the daemon to stop a transfer the bridge is showing.
  function cancelTransfer(id) {
    if (id.indexOf("kdc:pending:") === 0) {
      root._finishPending("cancelled");
      return;
    }
    cancelCall.exec(["busctl", "--user", "call", "org.kde.JobViewServer", "/JobViewServer", "org.kde.PhoneBridge", "cancel", "s", id]);
  }

  // ---- the phone's storage ----

  // The panel's message when the phone would not share its files, "" when there is none.
  property string browseError: ""
  property bool mounting: false

  // What a mount is for: "open" in the file manager, or "pick" for the wallpaper chooser.
  property string _mountFor: ""

  signal mounted(string path, string purpose)
  signal mountFailed(string purpose)

  // The daemon's SFTP mount of the phone, started if it is not up: `mountAndWait` says whether
  // it is, and `getMountError` why not. Its default directory handler is not used, since it is
  // whatever the desktop has for folders (a terminal, here); the file manager is named.
  function mount(purpose) {
    if (!connected || mounting)
      return;
    root.browseError = "";
    root.mounting = true;
    root._mountFor = purpose;
    mountCall.exec(root._busctl("sftp", "mountAndWait"));
  }

  function browse() {
    root.mount("open");
  }

  function _busctl(plugin, member) {
    return ["busctl", "--user", "--json=short", "call", "org.kde.kdeconnect", root._plugin(plugin), "org.kde.kdeconnect.device." + plugin, member];
  }

  // The value of `busctl --json=short`'s single reply, or null.
  function _reply(text) {
    try {
      return JSON.parse(text).data[0];
    } catch (err) {
      return null;
    }
  }

  function _mountFailed(message) {
    root.mounting = false;
    if (/permission/i.test(message))
      root.browseError = "Allow file access in KDE Connect on your phone";
    else
      root.browseError = "Could not open the phone's files";
    root.mountFailed(root._mountFor);
  }

  Command {
    id: mountCall

    label: "Mount phone"
    stdout: StdioCollector {
      onStreamFinished: {
        if (root._reply(text) === true)
          mountPointCall.exec(root._busctl("sftp", "mountPoint"));
        else
          mountErrorCall.exec(root._busctl("sftp", "getMountError"));
      }
    }
  }

  Command {
    id: mountPointCall

    label: "Phone mount point"
    stdout: StdioCollector {
      onStreamFinished: {
        var path = root._reply(text);
        if (typeof path !== "string" || path === "") {
          root._mountFailed("");
          return;
        }
        root.mounting = false;
        if (root._mountFor === "open")
          Launch.run(["nautilus", path], "nautilus");
        root.mounted(path, root._mountFor);
      }
    }
  }

  Command {
    id: mountErrorCall

    label: "Phone mount error"
    stdout: StdioCollector {
      onStreamFinished: root._mountFailed(root._reply(text) || "")
    }
  }

  // ---- the wallpaper drawn on the phone preview ----

  // The picture the user chose, as a file in the state directory: a copy, so it outlives the
  // phone (the original is on its storage). One at a time, named afresh for each so the image
  // cache does not keep the old one.
  readonly property string wallpaper: wallpaperState.value !== "" ? "file://" + wallpaperState.value : ""

  function setWallpaper(path) {
    var ext = /\.([A-Za-z0-9]+)$/.exec(String(path));
    var to = Paths.stateDir + "/phone-wallpaper-" + Date.now() + "." + (ext ? ext[1].toLowerCase() : "img");
    wallpaperCopy.copyTo = to;
    wallpaperCopy.exec(["sh", "-c", 'cp -- "$1" "$2" && find "$3" -maxdepth 1 -name "phone-wallpaper-*" ! -path "$2" -delete', "sh", path, to, Paths.stateDir]);
  }

  Command {
    id: wallpaperCopy

    property string copyTo: ""

    label: "Copy phone wallpaper"
  }

  Connections {
    target: wallpaperCopy

    function onExited(code) {
      if (code === 0)
        wallpaperState.save(wallpaperCopy.copyTo);
    }
  }

  PersistedValue {
    id: wallpaperState

    name: "phone-wallpaper"
  }

  onConnectedChanged: if (!connected)
    root.ringing = false
}
