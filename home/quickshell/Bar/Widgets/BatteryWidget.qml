import QtQuick
import Quickshell.Services.UPower
import qs.Commons

IconWidget {
  id: root

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery !== null && battery.isLaptopBattery && battery.isPresent
  readonly property int percent: present ? Math.round(battery.percentage * 100) : 0
  readonly property bool charging: present && battery.state === UPowerDeviceState.Charging
  readonly property bool full: present && battery.state === UPowerDeviceState.FullyCharged

  visible: present

  glyph: {
    if (!present)
      return "";
    if (full)
      return Icons.batteryFull;
    return Icons.step(charging ? Icons.batteryCharging : Icons.batteryDefault, percent);
  }

  label: (charging || full) ? "" : percent + "%"
  labelFirst: true
  gap: Theme.spacingSm

  glyphColor: {
    if (!present || charging || full)
      return Theme.text;
    if (percent <= 10)
      return Theme.love;
    if (percent <= 20)
      return Theme.gold;
    return Theme.text;
  }

  readonly property string tooltip: {
    if (!present)
      return "";
    var watts = Math.round(battery.changeRate);
    if (charging)
      return watts + "W↑ " + percent + "%";
    if (full)
      return "Fully charged";
    return watts + "W↓ " + percent + "%";
  }
}
