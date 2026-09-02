pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Firmware emits no Fn+Space event, so poll sysfs. LED writes need a udev rule.
Singleton {
  id: root

  readonly property real value: _max > 0 ? level / _max : 0
  property int level: 0
  property bool available: false

  // Discover the LED because sysfs device names vary by vendor.
  property string devicePath: ""

  property int _max: 0

  // Polling exists only to catch keypresses, and those arrive in bursts. Idle
  // slowly, then drop to 100 ms for a few seconds after any observed change.
  // Adjusting the backlight means tapping the key several times, so every press
  // after the first lands twice as fast as the old flat 200 ms, and the session
  // pays 2.5x fewer idle wakeups for it.
  readonly property int idleInterval: 400
  readonly property int burstInterval: 100
  readonly property int burstDuration: 3000

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
    // inotify does not fire on sysfs, so this never substitutes for the poll.
    watchChanges: true

    onFileChanged: currentFile.reload()

    onLoaded: {
      if (root._max <= 0)
        return;
      var current = parseInt(currentFile.text());
      if (!isFinite(current))
        return;
      // Re-enter the fast window on every real change, including the first.
      if (current !== root.level || !root.available)
        burst.restart();
      root.level = current;
      root.available = true;
    }
  }

  Timer {
    id: burst
    interval: root.burstDuration
  }

  Timer {
    running: root.devicePath !== ""
    interval: burst.running ? root.burstInterval : root.idleInterval
    repeat: true
    onTriggered: currentFile.reload()
  }
}
