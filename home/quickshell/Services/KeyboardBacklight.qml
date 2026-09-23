pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Firmware emits no Fn+Space event, so poll sysfs. LED writes need a udev rule.
Singleton {
  id: root

  readonly property real value: gauge.value
  readonly property bool available: gauge.available

  // Polling catches keypresses, which arrive in bursts: idle slowly, then drop to 100 ms
  // for a few seconds after a change, saving 2.5x idle wakeups over the old flat 200 ms.
  readonly property int idleInterval: 400
  readonly property int burstInterval: 100
  readonly property int burstDuration: 3000

  property int level: 0

  SysfsGauge {
    id: gauge

    glob: "/sys/class/leds/*kbd_backlight*"
    // inotify does not fire on sysfs, so the watch can never fire; the poll covers it.
    watch: false

    onValueChanged: {
      var current = Math.round(gauge.value * gauge.max);
      // Re-enter the fast window on every real change, including the first.
      if (current !== root.level || !gauge.available)
        burst.restart();
      root.level = current;
    }
  }

  Timer {
    id: burst

    interval: root.burstDuration
  }

  Timer {
    running: gauge.devicePath !== ""
    interval: burst.running ? root.burstInterval : root.idleInterval
    repeat: true
    onTriggered: gauge.reload()
  }
}
