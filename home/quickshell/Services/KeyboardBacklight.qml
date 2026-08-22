pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fn+Space is handled by firmware and emits no input event or watchable kernel
// notification. Poll sysfs for firmware changes and watch it for userspace
// writes. LED writes require a udev rule, so this service is read-only.
Singleton {
  id: root

  // 0..1
  readonly property real value: _max > 0 ? level / _max : 0
  property int level: 0
  property bool available: false

  // Discover the LED because sysfs device names vary by vendor.
  property string devicePath: ""

  property int _max: 0

  Process {
    id: findDevice
    running: true
    command: ["sh", "-c", "for d in /sys/class/leds/*kbd_backlight*; do [ -r \"$d/brightness\" ] && { echo \"$d\"; exit 0; }; done"]
    stdout: StdioCollector {
      onStreamFinished: root.devicePath = text.trim()
    }
  }

  FileView {
    id: maxFile
    path: root.devicePath === "" ? "" : root.devicePath + "/max_brightness"
    onLoaded: {
      var m = parseInt(maxFile.text());
      if (isFinite(m) && m > 0) {
        root._max = m;
        currentFile.reload();
      }
    }
  }

  FileView {
    id: currentFile

    path: root.devicePath === "" ? "" : root.devicePath + "/brightness"
    watchChanges: true

    onFileChanged: currentFile.reload()

    onLoaded: {
      if (root._max <= 0)
        return;
      var current = parseInt(currentFile.text());
      if (!isFinite(current))
        return;
      root.level = current;
      root.available = true;
    }
  }

  // A 200 ms poll keeps OSD feedback tied to firmware keypresses.
  Timer {
    running: root.devicePath !== ""
    interval: 200
    repeat: true
    onTriggered: currentFile.reload()
  }
}
