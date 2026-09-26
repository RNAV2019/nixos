pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons

// The battery gauges and status both read the display device; reading it once here keeps
// one subscription and one definition of "present".
Singleton {
  id: root

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery !== null && battery.isLaptopBattery && battery.isPresent
  readonly property bool charging: present && battery.state === UPowerDeviceState.Charging
  readonly property bool plugged: charging || (present && (battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge))
  readonly property bool discharging: present && battery.state === UPowerDeviceState.Discharging

  // Clamped 0..1 for direct gauge consumption.
  readonly property real level: present ? Theme.clamp01(battery.percentage) : 0

  // UPower's energy rate is the battery's flow: system draw on battery, cell input while charging.
  readonly property real watts: present ? Math.abs(battery.changeRate) : 0

  // Warn on the way down: once at the low mark, once more, critical, at the critical one.
  readonly property real lowLevel: 0.2
  readonly property real criticalLevel: 0.1
  property bool _ready: false

  onLevelChanged: _checkLevel()
  onDischargingChanged: _checkLevel()
  onPluggedChanged: _checkLevel()

  function _checkLevel() {
    if (!_ready)
      return;
    if (plugged) {
      warned.stage = 0;
      return;
    }
    if (!discharging)
      return;
    var stage = level <= criticalLevel ? 2 : level <= lowLevel ? 1 : 0;
    if (stage <= warned.stage)
      return;
    warned.stage = stage;
    _warn(stage === 2);
  }

  function _warn(critical) {
    var body = Math.round(level * 100) + "% remaining";
    var mins = Math.round(battery.timeToEmpty / 60);
    if (mins > 0)
      body += ", about " + (mins >= 60 ? Math.floor(mins / 60) + " h " : "") + (mins % 60) + " min left";
    warning.command = ["notify-send", "-a", "Battery", "-u", critical ? "critical" : "normal", "-i", critical ? "battery-caution" : "battery-low", critical ? "Battery critically low" : "Battery low", body];
    warning.running = true;
  }

  // The stage already warned for survives a config reload, so editing the shell does not re-warn.
  PersistentProperties {
    id: warned

    property int stage: 0

    reloadableId: "batteryWarning"

    onLoaded: {
      root._ready = true;
      root._checkLevel();
    }
  }

  // The shell is the notification server, so this comes back as its own toast.
  Process {
    id: warning
  }
}
