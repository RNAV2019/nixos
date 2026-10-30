pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The phone, through KDE Connect. Quickshell has no D-Bus client, so `phone-bridge events`
// (pkgs/phone-bridge) watches kdeconnectd on the session bus and prints the whole picture as a
// JSON line whenever it changes: paired devices that are reachable (or asking to pair), each with
// its battery and the notifications it has up. The controls go the other way, straight to the
// daemon with `busctl`, so each is one visible D-Bus call: ring, accept or reject a pairing,
// dismiss a notification, send this machine's clipboard.
//
// The phone is the first paired and reachable smartphone (else tablet). Activities/PhoneSource.qml
// turns it into the pinned satellite and raises the pairing moment; Activities/PhoneCard.qml is
// its hover card. A phone's own notifications are also shown by kdeconnectd as desktop
// notifications, which the shell's server turns into toasts; the list here is what is still up.
//
// Clipboard. KDE Connect hands what the phone copies to this machine's clipboard as plain text,
// with nothing to tell it from anything else, and offers no signal or property for it. So the card
// cannot say "from the phone": it shows the text now on this machine's clipboard (read with
// `wl-paste --watch`, never a password manager's) and sends it to the phone on request.
//
// Screen preview. Off unless an adb device is connected over wireless debugging at one of the
// phone's addresses (README); then the card takes one `adb exec-out screencap` per second, only
// while it is open.
Singleton {
  id: root

  // ---- the picture from phone-bridge ----

  property bool daemon: false
  property var devices: []

  // The one shown last stays the phone while it is paired and reachable, so a second device
  // appearing does not take the satellite from it.
  property string _held: ""

  readonly property var phone: {
    var pick = null;
    for (var i = 0; i < root.devices.length; i++) {
      var d = root.devices[i];
      if (!d.paired || !d.reachable || (d.type !== "smartphone" && d.type !== "tablet"))
        continue;
      if (d.id === root._held)
        return d;
      if (pick === null || (pick.type === "tablet" && d.type === "smartphone"))
        pick = d;
    }
    return pick;
  }

  onPhoneChanged: root._held = phone !== null ? phone.id : ""

  readonly property bool connected: phone !== null
  readonly property string deviceId: phone ? phone.id : ""
  readonly property string name: phone ? phone.name : ""
  readonly property string link: phone ? phone.link : ""
  readonly property bool hasBattery: phone !== null && phone.battery !== null
  readonly property int charge: hasBattery ? phone.battery.charge : -1
  readonly property bool charging: hasBattery && phone.battery.charging
  readonly property bool low: hasBattery && !charging && charge <= Theme.phoneLowBattery

  // Devices that have asked to pair and are waiting for an answer.
  readonly property var pairing: root.devices.filter(function (d) {
    return d.pairRequested && !d.paired;
  })

  // The phone's notifications, newest first; only reassigned when one changes, so the card's
  // rows are not rebuilt by a battery reading.
  property var notifications: []

  // "Connected · Wi-Fi", the card's caption.
  readonly property string caption: link !== "" ? "Connected · " + link : "Connected"

  function _apply(state) {
    root.daemon = state.daemon === true;
    root.devices = state.devices || [];
    var next = root.phone !== null ? root.phone.notifications : [];
    if (JSON.stringify(next) !== JSON.stringify(root.notifications))
      root.notifications = next;
  }

  // ---- the bridge process ----

  property int _restart: 5000

  Process {
    id: bridge

    command: ["phone-bridge", "events"]
    running: true

    stdout: SplitParser {
      onRead: function (line) {
        var state;
        try {
          state = JSON.parse(line);
        } catch (err) {
          return;
        }
        root._restart = 5000;
        root._apply(state);
      }
    }

    // Nothing to show once it is gone; it is started again after a pause that doubles up to a
    // minute, which is also what a shell without phone-bridge on its PATH sees.
    onExited: function (code) {
      root._apply({});
      console.warn("phone-bridge exited (" + code + "), restarting in " + root._restart / 1000 + " s");
      retry.interval = root._restart;
      root._restart = Math.min(60000, root._restart * 2);
      retry.start();
    }
  }

  Timer {
    id: retry

    onTriggered: bridge.running = true
  }

  // ---- calling kdeconnectd ----

  Component {
    id: caller

    Command {
      onExited: destroy(100)
    }
  }

  function _call(path, iface, member, what) {
    var run = caller.createObject(root, {
      label: what
    });
    run.exec(["busctl", "--user", "call", "org.kde.kdeconnect", path, iface, member]);
  }

  function _devicePath(id) {
    return "/modules/kdeconnect/devices/" + id;
  }

  // Make the phone ring, which it does until someone picks it up.
  property bool ringing: false

  function ring() {
    if (!connected)
      return;
    root._call(_devicePath(deviceId) + "/findmyphone", "org.kde.kdeconnect.device.findmyphone", "ring", "Ring phone");
    root.ringing = true;
    ringReset.restart();
  }

  Timer {
    id: ringReset

    interval: 3000
    onTriggered: root.ringing = false
  }

  function acceptPairing(id) {
    root._call(_devicePath(id), "org.kde.kdeconnect.device", "acceptPairing", "Accept pairing");
  }

  function rejectPairing(id) {
    root._call(_devicePath(id), "org.kde.kdeconnect.device", "cancelPairing", "Reject pairing");
  }

  function dismiss(notificationId) {
    if (!connected)
      return;
    root._call(_devicePath(deviceId) + "/notifications/" + notificationId, "org.kde.kdeconnect.device.notifications.notification", "dismiss", "Dismiss phone notification");
  }

  // ---- the clipboard ----

  // What is on this machine's clipboard as text, when it changed (0 for what was already there
  // when the watch began), and what was last sent to the phone and when.
  property string clipText: ""
  property real clipAt: 0
  property string sentText: ""
  property real sentAt: 0
  property bool _clipSeen: false

  function sendClipboard() {
    if (!connected || clipText === "")
      return;
    root._call(_devicePath(deviceId) + "/clipboard", "org.kde.kdeconnect.device.clipboard", "sendClipboard", "Send clipboard to phone");
    root.sentText = root.clipText;
    root.sentAt = Date.now();
  }

  Process {
    id: clipWatch

    command: ["wl-paste", "--type", "text", "--watch", "phone-bridge", "clip"]
    running: root.connected

    stdout: SplitParser {
      onRead: function (line) {
        var ev;
        try {
          ev = JSON.parse(line);
        } catch (err) {
          return;
        }
        if (ev.event !== "clip")
          return;
        // A password manager's copy is not shown, and what it replaced is not shown either.
        if (ev.secret) {
          root.clipText = "";
          return;
        }
        if (ev.text === "" || ev.text === root.clipText)
          return;
        root.clipText = ev.text;
        root.clipAt = root._clipSeen ? Date.now() : 0;
        root._clipSeen = true;
      }
    }

    onRunningChanged: if (!running) {
      root._clipSeen = false;
    }
  }

  onConnectedChanged: {
    if (!connected) {
      root.clipText = "";
      root.clipAt = 0;
      root.sentText = "";
      root.ringing = false;
      root.previewSerial = "";
      root.previewFrame = 0;
      root._wipe();
    } else {
      root.findPreview();
    }
  }

  // ---- the screen preview ----

  property string previewSerial: ""
  // Counts the frames taken; they alternate between two files so the card's image swaps from one
  // complete picture to the next.
  property int previewFrame: 0
  readonly property bool previewAvailable: previewSerial !== ""
  readonly property bool cardOpen: Activities.cardKey === "phone"

  readonly property string previewDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-phone"
  readonly property string previewUrl: previewFrame > 0 ? "file://" + previewDir + "/screen-" + (previewFrame % 2) + ".png" : ""

  property int _failures: 0

  // Looks for an adb device at one of the phone's addresses; run when the phone connects and
  // whenever its card opens, which is when the answer matters.
  function findPreview() {
    if (!connected || phone.addresses.length === 0 || finder.running)
      return;
    finder.command = ["phone-bridge", "adb"].concat(phone.addresses);
    finder.running = true;
  }

  onCardOpenChanged: if (cardOpen)
    findPreview()

  Process {
    id: finder

    stdout: StdioCollector {
      id: found
    }

    onExited: function (code) {
      var serial = code === 0 ? found.text.trim() : "";
      if (serial !== root.previewSerial) {
        root.previewSerial = serial;
        if (serial === "")
          root.previewFrame = 0;
      }
      root._failures = 0;
    }
  }

  Timer {
    interval: Theme.phonePreviewInterval
    running: root.previewAvailable && root.cardOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!shot.running) {
      shot.next = root.previewFrame + 1;
      shot.command = ["phone-bridge", "shot", root.previewSerial, root.previewDir + "/screen-" + (shot.next % 2) + ".png"];
      shot.running = true;
    }
  }

  Process {
    id: shot

    property int next: 0

    onExited: function (code) {
      if (code === 0) {
        root._failures = 0;
        root.previewFrame = shot.next;
        return;
      }
      // Three misses in a row: the phone is not there for adb any more.
      root._failures += 1;
      if (root._failures >= 3) {
        root.previewSerial = "";
        root.previewFrame = 0;
        root._failures = 0;
      }
    }
  }

  function _wipe() {
    wipe.command = ["rm", "-rf", root.previewDir];
    wipe.running = true;
  }

  Process {
    id: wipe
  }
}
