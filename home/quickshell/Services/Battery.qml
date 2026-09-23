pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Commons

// The battery gauges and status both read the display device; reading it once here keeps
// one subscription and one definition of "present".
Singleton {
  id: root

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery !== null && battery.isLaptopBattery && battery.isPresent
  readonly property bool charging: present && battery.state === UPowerDeviceState.Charging

  // Clamped 0..1 for direct gauge consumption.
  readonly property real level: present ? Theme.clamp01(battery.percentage) : 0

  // UPower's energy rate is the battery's flow: system draw on battery, cell input while charging.
  readonly property real watts: present ? Math.abs(battery.changeRate) : 0
}
