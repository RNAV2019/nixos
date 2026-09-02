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

  // Emitted per keypress, including when the value is already railed, so the
  // OSD can appear without waiting on a sysfs change that never comes.
  signal adjusted

  // -e spends the raw range on an exponential curve, so a step at the dim end
  // does not swamp the one before it. That makes each step a proportion of the
  // current level rather than of the maximum, so it takes a smaller percentage
  // than a linear control would to land on the same feel.
  function step(up) {
    // --min-value keeps the key off a fully black panel. It has to be joined by
    // = because a separate argument is parsed as the operation instead.
    setter.command = ["brightnessctl", "-e", "--min-value=4", "set", up ? "2.5%+" : "2.5%-"];
    setter.running = true;
    root.adjusted();
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
