import QtQuick
import QtQuick.Shapes

// The Wi-Fi mark the island's status gauge draws: three quarter-arcs over a dot, lit by signal
// strength. Shared so the control centre's tile draws the same mark, and mirrored by
// Assets/notification-icons/wifi.svg for NetworkManager's notifications.
Item {
  id: root

  // Signal strength 0..1; the inner arc and dot light on any connection.
  property real strength: 0
  property bool connected: false
  property color litColor
  property color dimColor

  // The arcs outweigh the dot, so the fan reads high when its box is centred. The box carries
  // twice this much room above the ink, so centring the box drops the mark by this much.
  readonly property real opticalDrop: 1.2

  readonly property real centreX: 12
  readonly property real centreY: 16.5 + opticalDrop * 2

  implicitWidth: 24
  implicitHeight: 19 + opticalDrop * 2

  component Bar: ShapePath {
    id: bar

    property real radius: 0
    property bool lit: false

    strokeColor: lit ? root.litColor : root.dimColor
    strokeWidth: 2.4
    capStyle: ShapePath.RoundCap
    fillColor: "transparent"

    PathAngleArc {
      centerX: root.centreX
      centerY: root.centreY
      radiusX: bar.radius
      radiusY: bar.radius
      startAngle: 225
      sweepAngle: 90
    }
  }

  // A Shape sizes itself to its paths, which leave out the dot; the Item above owns the box.
  Shape {
    preferredRendererType: Shape.CurveRenderer

    Bar {
      radius: 14.5
      lit: root.strength >= 0.66
    }

    Bar {
      radius: 10
      lit: root.strength >= 0.33
    }

    Bar {
      radius: 5.5
      lit: root.connected
    }
  }

  Rectangle {
    x: root.centreX - 1.8
    y: root.centreY - 1.8
    width: 3.6
    height: 3.6
    radius: 1.8
    color: root.connected ? root.litColor : root.dimColor
  }
}
