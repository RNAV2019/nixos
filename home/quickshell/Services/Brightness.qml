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

  // Every control works in the raw sysfs range, which is also the space
  // `value` reports and the panel slider draws. brightnessctl's -e flag would
  // put a step or a target somewhere up an exponential curve instead, which
  // leaves the reported percentage disagreeing with what was asked for.
  readonly property int stepPercent: 5

  // A flat 5% step is right for a tap but slow for a hold: the keyboard
  // repeats 25 times a second, so crossing the range takes 20 of them. Once a
  // run of presses is clearly a held key rather than tapping, grow the step so
  // the ends arrive in roughly half a second while a single press stays fine.
  readonly property int maxStepPercent: 20
  readonly property int stepGrowth: 2
  // Presses at the base size before the run starts accelerating.
  readonly property int accelAfter: 5
  // Repeats arrive 40 ms apart, so this separates a held key from tapping.
  readonly property int repeatWindow: 150

  property int _run: 0
  property real _lastAt: 0
  property bool _lastUp: false

  function step(up) {
    var now = Date.now();
    // Reversing direction restarts the ramp, so a correction is not amplified.
    var continues = up === _lastUp && (now - _lastAt) < repeatWindow;
    _run = continues ? _run + 1 : 0;
    _lastAt = now;
    _lastUp = up;

    var pct = Math.min(maxStepPercent, stepPercent + Math.max(0, _run - accelAfter) * stepGrowth);

    // --min-value keeps the key off a fully black panel. It has to be joined by
    // = because a separate argument is parsed as the operation instead.
    setter.command = ["brightnessctl", "--min-value=4", "set", pct + (up ? "%+" : "%-")];
    setter.running = true;
    root.adjusted();
  }

  // The panel slider's absolute target, in the same linear space as the steps.
  function set(v) {
    var pct = Math.round(Math.max(0, Math.min(1, v)) * 100);
    setter.command = ["brightnessctl", "--min-value=4", "set", pct + "%"];
    setter.running = true;
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
