import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Services

// Drawn rather than set in an icon font, so it tints with the accent and stays
// crisp at the one size the status pill uses. Arcs fade out below the signal
// they represent, and all three drop when nothing is connected.
Item {
  id: root

  component Arc: ShapePath {
    id: arc

    property real x0: 0
    property real x1: 0
    property real yBase: 0
    property real yApex: 0

    strokeWidth: 2.2
    capStyle: ShapePath.RoundCap
    fillColor: "transparent"
    startX: x0
    startY: yBase

    // A quadratic whose control point sits twice as far out as the apex passes
    // exactly through that apex at its midpoint.
    PathQuad {
      x: arc.x1
      y: arc.yBase
      controlX: (arc.x0 + arc.x1) / 2
      controlY: 2 * arc.yApex - arc.yBase
    }
  }

  readonly property bool connected: NetworkInfo.onEthernet || NetworkInfo.activeNetwork !== null

  // Ethernet has no signal to grade, so it lights every arc.
  readonly property real strength: {
    if (NetworkInfo.onEthernet)
      return 1;
    if (!NetworkInfo.activeNetwork)
      return 0;
    return NetworkInfo.activeNetwork.signalStrength;
  }

  function arcColor(lit) {
    return Theme.withAlpha(Theme.accent, lit ? 1 : 0.3);
  }

  implicitWidth: 15
  implicitHeight: 15

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    Arc {
      x0: 1.3
      x1: 13.8
      yBase: 5.3
      yApex: 3.3
      strokeColor: root.arcColor(root.strength >= 0.66)
    }

    Arc {
      x0: 3.1
      x1: 11.9
      yBase: 7.8
      yApex: 6.4
      strokeColor: root.arcColor(root.strength >= 0.33)
    }

    Arc {
      x0: 5.3
      x1: 9.7
      yBase: 10.3
      yApex: 9.7
      strokeColor: root.arcColor(root.connected)
    }
  }

  // The base dot, which is present whether or not there is a signal.
  Rectangle {
    x: 6.2
    y: 11.2
    width: 2.6
    height: 2.6
    radius: width / 2
    color: root.arcColor(root.connected)
  }
}
