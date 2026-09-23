import QtQuick
import QtQuick.Shapes
import qs.Ui
import qs.Commons
import qs.Services

// Board 02's battery gauge: a ring that is the battery, open at the bottom, with the Wi-Fi
// glyph inside and the charge in the gap. On the charger the ring turns foam and gains a bolt.
Gauge {
  id: root

  readonly property bool plugged: Battery.charging || (Battery.present && (Battery.battery.state === UPowerDeviceState.FullyCharged || Battery.battery.state === UPowerDeviceState.PendingCharge))
  readonly property bool low: Battery.present && !plugged && Battery.level <= 0.2

  readonly property color tint: plugged ? Theme.foam : low ? Theme.love : Theme.accent

  value: Battery.level
  strokeColor: root.tint

  Behavior on strokeColor {
    Tint {}
  }

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

  Rectangle {
    x: 24 - 1.8
    y: 31 - 1.8
    width: 3.6
    height: 3.6
    radius: 1.8
    color: root.barColor(root.connected)
  }

  // The charge, led by a bolt while on the charger.
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.islandGaugeLabelY
    spacing: 2
    visible: Battery.present

    Shape {
      anchors.verticalCenter: parent.verticalCenter
      width: root.plugged ? 7 : 0
      height: 10
      visible: root.plugged
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: Theme.foam
        strokeColor: Theme.foam
        strokeWidth: 0.6
        joinStyle: ShapePath.RoundJoin
        startX: 4.4
        startY: 0.3

        PathLine { x: 0.5; y: 5.9 }
        PathLine { x: 3.4; y: 5.9 }
        PathLine { x: 2.6; y: 9.7 }
        PathLine { x: 6.5; y: 4.1 }
        PathLine { x: 3.6; y: 4.1 }
        PathLine { x: 4.4; y: 0.3 }
      }
    }

    GaugeLabel {
      text: Math.round(Battery.level * 100) + "%"
      color: root.plugged ? Theme.foam : root.low ? Theme.love : Theme.subtle
    }
  }
}
