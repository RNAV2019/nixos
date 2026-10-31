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
// What KDE Connect cannot say, the panel does without: the phone's own Wi-Fi is not reported,
// but a LAN link means it shares this machine's network, so that network's name stands in; a
// ring cannot be stopped from here; and copies from the phone land on this machine's clipboard
// with nothing to tell them apart, so the clipboard rows are cliphist's history, unattributed.
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
    id: clipboardCall

    label: "Send clipboard to phone"
  }

  Command {
    id: shareCall

    label: "Send files to phone"
  }

  Command {
    id: browseCall

    label: "Browse phone"
  }

  Command {
    id: dismissCall

    label: "Dismiss phone notification"
  }

  function _call(run, path, iface, member, args) {
    run.exec(["busctl", "--user", "call", "org.kde.kdeconnect", path, iface, member].concat(args || []));
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

  function sendClipboard() {
    if (connected)
      root._call(clipboardCall, _plugin("clipboard"), "org.kde.kdeconnect.device.clipboard", "sendClipboard");
  }

  // Absolute paths; folders are sent as KDE Connect sends them.
  function share(paths) {
    if (!connected || paths.length === 0)
      return;
    var urls = paths.map(function (p) {
      return "file://" + encodeURI(p);
    });
    root._call(shareCall, _plugin("share"), "org.kde.kdeconnect.device.share", "shareUrls", ["as", String(urls.length)].concat(urls));
  }

  // Mounts the phone's storage over SFTP and opens it in the file manager.
  function browse() {
    if (connected)
      root._call(browseCall, _plugin("sftp"), "org.kde.kdeconnect.device.sftp", "startBrowsing");
  }

  function dismiss(notificationId) {
    if (connected)
      root._call(dismissCall, _plugin("notifications") + "/" + notificationId, "org.kde.kdeconnect.device.notifications.notification", "dismiss");
  }

  onConnectedChanged: if (!connected)
    root.ringing = false

  // ---- the clipboard rows ----

  // The newest text clips from cliphist, parsed as the launcher parses them.
  property var clips: []

  function refreshClips() {
    clipList.run();
  }

  function copyClip(id) {
    ClipboardHistory.copy(id);
  }

  QueuedProcess {
    id: clipList

    command: ["sh", "-c", "cliphist -preview-width 120 list | head -n 30"]

    stdout: StdioCollector {
      onStreamFinished: {
        var out = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length && out.length < Theme.phoneClipsMax; i++) {
          var e = lines[i].length > 0 ? ClipboardHistory.parse(lines[i]) : null;
          if (e && !e.size && e.preview.trim() !== "")
            out.push(e);
        }
        root.clips = out;
      }
    }
  }
}
