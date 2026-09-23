pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Watch sysfs for brightness events and write through brightnessctl.
Singleton {
  id: root

  property real value: gauge.value
  property bool available: gauge.available

  // Emitted per keypress, even at a rail, so the OSD appears without a sysfs change.
  signal adjusted

  // Everything works in the raw sysfs range, which `value` and the slider share.
  // brightnessctl's -e flag would put a step up an exponential curve and disagree.
  readonly property int stepPercent: 5

  // A flat 5% step suits a tap but not a hold: the key repeats 25 times a second, so
  // crossing the range takes 20. After a run, grow the step to arrive in ~0.5 s.
  readonly property int maxStepPercent: 20
  readonly property int stepGrowth: 2
  // Presses at the base size before the run starts accelerating.
  readonly property int accelAfter: 5
  // Repeats arrive 40 ms apart, so this separates a held key from tapping.
  readonly property int repeatWindow: 150

  property int _run: 0
  property real _lastAt: 0
  property bool _lastUp: false

  // Slider and key repeat outrun brightnessctl, so keep the latest target and one writer.
  // (Volume.qml carries the same throttle shape; the queues differ - a latest target
  // here, a pending delta there - so the writer stays per-service.)
  readonly property int writeInterval: 20
  property real _requestedValue: 0
  property bool _hasRequestedValue: false
  property real _lastTarget: 0
  property bool _hasLastTarget: false
  property real _lastWriteAt: 0

  SysfsGauge {
    id: gauge

    glob: "/sys/class/backlight/*"
  }

  function clamp(v) {
    return Math.max(0, Math.min(1, v));
  }

  function baseValue() {
    if (_hasRequestedValue)
      return _requestedValue;
    if (_hasLastTarget)
      return _lastTarget;
    return root.value;
  }

  function queueValue(v) {
    _requestedValue = root.clamp(v);
    _hasRequestedValue = true;
    writeTimer.restart();
  }

  function flushValue() {
    if (!_hasRequestedValue || setter.running)
      return;

    var elapsed = Date.now() - _lastWriteAt;
    if (_lastWriteAt > 0 && elapsed < writeInterval) {
      writeTimer.restart();
      return;
    }

    var target = _requestedValue;
    _hasRequestedValue = false;
    if (_hasLastTarget && Math.abs(target - _lastTarget) < 0.005)
      return;

    _lastTarget = target;
    _hasLastTarget = true;
    _lastWriteAt = Date.now();
    setter.command = ["brightnessctl", "--min-value=4", "set", Math.round(target * 100) + "%"];
    setter.running = true;
  }

  function step(up) {
    var now = Date.now();
    // Reversing direction restarts the ramp, so a correction is not amplified.
    var continues = up === _lastUp && (now - _lastAt) < repeatWindow;
    _run = continues ? _run + 1 : 0;
    _lastAt = now;
    _lastUp = up;

    var pct = Math.min(maxStepPercent, stepPercent + Math.max(0, _run - accelAfter) * stepGrowth);
    queueValue(baseValue() + (up ? pct : -pct) / 100);
    root.adjusted();
  }

  // The panel slider's absolute target, in the same linear space as the steps.
  function set(v) {
    queueValue(v);
  }

  onValueChanged: {
    if (!_hasRequestedValue && !setter.running) {
      _lastTarget = root.value;
      _hasLastTarget = true;
    }
  }

  Timer {
    id: writeTimer

    interval: root.writeInterval
    repeat: false
    onTriggered: root.flushValue()
  }

  Process {
    id: setter

    onRunningChanged: if (!setter.running)
      root.flushValue()
  }
}
