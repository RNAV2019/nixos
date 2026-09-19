import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs.Commons
import qs.Services

// Board 02's status gauge: a ring that is the battery, open at the bottom, with the Wi-Fi
// glyph inside it and the system's power draw sitting in the gap.
Item {
  id: root

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery !== null && battery.isLaptopBattery && battery.isPresent
  readonly property real level: present ? Math.max(0, Math.min(1, battery.percentage)) : 0
  readonly property bool charging: present && battery.state === UPowerDeviceState.Charging
  readonly property bool low: present && !charging && level <= 0.2

  // UPower's energy rate is the battery's own flow: the whole system's draw while on
  // battery, what goes into the cell while charging.
  readonly property real watts: present ? Math.abs(battery.changeRate) : 0

  readonly property real startAngle: 150
  readonly property real sweep: 240

  readonly property bool connected: NetworkInfo.onEthernet || NetworkInfo.activeNetwork !== null
  readonly property real strength: {
    if (NetworkInfo.onEthernet)
      return 1;
    if (!NetworkInfo.activeNetwork)
      return 0;
    return NetworkInfo.activeNetwork.signalStrength;
  }

  component WifiBar: ShapePath {
    id: bar

    property real radius: 0
    property bool lit: false

    strokeColor: root.barColor(lit)
    strokeWidth: 2.4
    capStyle: ShapePath.RoundCap
    fillColor: "transparent"

    PathAngleArc {
      centerX: 24
      centerY: 31
      radiusX: bar.radius
      radiusY: bar.radius
      startAngle: 225
      sweepAngle: 90
    }
  }

  function barColor(lit) {
    return lit ? Theme.text : Theme.highlightHigh;
  }

  implicitWidth: 48
  implicitHeight: 52

  Shape {
    width: 48
    height: 48
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: Theme.highlightMed
      strokeWidth: 4
      capStyle: ShapePath.RoundCap
      fillColor: "transparent"

      PathAngleArc {
        centerX: 24
        centerY: 24
        radiusX: 21
        radiusY: 21
        startAngle: root.startAngle
        sweepAngle: root.sweep
      }
    }

    ShapePath {
      strokeColor: root.low ? Theme.love : Theme.accent
      strokeWidth: root.present && root.level > 0 ? 4 : 0
      capStyle: ShapePath.RoundCap
      fillColor: "transparent"

      PathAngleArc {
        id: fill

        centerX: 24
        centerY: 24
        radiusX: 21
        radiusY: 21
        startAngle: root.startAngle
        sweepAngle: root.sweep * root.level

        Behavior on sweepAngle {
          NumberAnimation {
            duration: Theme.duration(Theme.morphState)
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    // Three bars about the dot, lit by signal strength.
    WifiBar {
      radius: 14.5
      lit: root.strength >= 0.66
    }

    WifiBar {
      radius: 10
      lit: root.strength >= 0.33
    }

    WifiBar {
      radius: 5.5
      lit: root.connected
    }
  }

  Rectangle {
    x: 24 - 1.8
    y: 31 - 1.8
    width: 3.6
    height: 3.6
    radius: 1.8
    color: root.barColor(root.connected)
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: 38
    visible: root.present
    text: (root.charging ? "↑ " : "↓ ") + root.watts.toFixed(1) + " W"
    color: Theme.subtle
    font.family: Theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
  }
}
