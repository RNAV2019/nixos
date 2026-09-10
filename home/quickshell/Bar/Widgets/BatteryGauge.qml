import QtQuick
import Quickshell.Services.UPower
import qs.Commons

// A drawn cell rather than a glyph, so the charge level is the shape itself and
// the reading sits inside it.
Item {
  id: root

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery !== null && battery.isLaptopBattery && battery.isPresent
  readonly property int percent: present ? Math.round(battery.percentage * 100) : 0
  readonly property bool charging: present && battery.state === UPowerDeviceState.Charging
  readonly property bool full: present && battery.state === UPowerDeviceState.FullyCharged

  // A charge that is nearly out has to break the accent, or it reads as a
  // normal reading in an unusual place.
  readonly property color tint: {
    if (charging || full)
      return Theme.foam;
    if (percent <= 10)
      return Theme.love;
    if (percent <= 20)
      return Theme.gold;
    return Theme.accent;
  }

  implicitWidth: 29.5
  implicitHeight: 14

  Rectangle {
    id: shell

    width: 26
    height: 14
    radius: 4.5
    color: "transparent"
    border.width: 1.5
    border.color: root.tint
  }

  Rectangle {
    x: 2
    y: 2
    width: Math.max(radius * 2, (shell.width - 4) * root.percent / 100)
    height: 10
    radius: 3
    color: Theme.withAlpha(root.tint, 0.35)

    Behavior on width {
      NumberAnimation {
        duration: Theme.morphState
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.morphCurve
      }
    }
  }

  Rectangle {
    x: 27
    y: 4
    width: 2.5
    height: 6
    radius: 1.25
    color: Theme.withAlpha(root.tint, 0.8)
  }

  Text {
    anchors.horizontalCenter: shell.horizontalCenter
    anchors.verticalCenter: shell.verticalCenter
    text: root.percent
    color: root.tint
    font.family: Theme.uiFont
    font.pixelSize: 9
    font.weight: Font.Bold
  }
}
