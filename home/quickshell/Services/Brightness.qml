pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Watch sysfs for brightness events and write through brightnessctl.
Singleton {
  id: root

  property real value: 0
  property bool available: false

  // Discover the backlight because sysfs device names vary by driver.
  property string devicePath: ""

  property int _max: 0

  function set(fraction) {
    var v = Math.max(0.01, Math.min(1, fraction));
    setter.command = ["brightnessctl", "set", Math.round(v * 100) + "%"];
    setter.running = true;
  }

  function step(delta) {
    set(value + delta);
  }

  Process {
    id: setter
  }

  Process {
    id: findDevice
    running: true
    command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && { echo \"$d\"; exit 0; }; done"]
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

    // Sysfs emits write and close notifications; duplicate reloads are safe.
    onFileChanged: currentFile.reload()

    onLoaded: {
      if (root._max <= 0)
        return;
      var current = parseInt(currentFile.text());
      if (!isFinite(current))
        return;
      root.value = current / root._max;
      root.available = true;
    }
  }
}
