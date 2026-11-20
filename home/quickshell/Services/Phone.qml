pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The phone, through KDE Connect. Quickshell has no D-Bus client, so `phone-bridge events`
// (pkgs/phone-bridge) watches kdeconnectd on the session bus and prints the whole picture as a
// JSON line whenever it changes: paired devices that are reachable (or asking to pair), each
// with its battery. Sending files goes the other way, straight to the daemon with `busctl`, so
// it is one visible D-Bus call.
//
// The phone is the first paired and reachable smartphone (else tablet). Bar/PhoneSatellite.qml
// buds out of the island while there is one, its battery on a ring; Nearby sends to it.
//
// Transfers come from the same process: it serves KDE's job tracker, so kdeconnectd's progress
// for what it sends and receives arrives as `transfer` lines, which Services/Nearby.qml takes
// into its own list. A send that finishes inside the tracker's half-second delay is never
// reported, so a share shows as sending from the call and is taken as done if no job turns up.
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
  readonly property bool hasBattery: phone !== null && phone.battery !== null
  readonly property int charge: hasBattery ? phone.battery.charge : -1
  readonly property bool charging: hasBattery && phone.battery.charging
  readonly property bool low: hasBattery && !charging && charge <= Theme.phoneLowBattery

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
}
