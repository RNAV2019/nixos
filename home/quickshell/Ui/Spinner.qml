import QtQuick
import QtQuick.Shapes
import qs.Commons

// The board's `Spinner`: a quarter arc turning over a faint ring, 20 px by default, with 2 px
// strokes and the ring inset by half a stroke, as the login pill draws it. It only turns while it
// is on screen.
Shape {
  id: root

  property real size: Theme.lockSpinnerSize
  property bool running: true

  property real stroke: 2
  // Off where something else already draws the ring it turns over.
  property bool track: true
  readonly property real ringRadius: (size - stroke) / 2

  implicitWidth: size
  implicitHeight: size
  antialiasing: true
  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    fillColor: "transparent"
    strokeColor: root.track ? Theme.withAlpha(Theme.inkTertiary, 0.35) : "transparent"
    strokeWidth: root.stroke

    PathAngleArc {
      centerX: root.width / 2
      centerY: root.height / 2
      radiusX: root.ringRadius
      radiusY: root.ringRadius
      startAngle: 0
      sweepAngle: 360
    }
  }

  ShapePath {
    fillColor: "transparent"
    strokeColor: Theme.accentFill
    strokeWidth: root.stroke
    capStyle: ShapePath.RoundCap

    PathAngleArc {
      centerX: root.width / 2
      centerY: root.height / 2
      radiusX: root.ringRadius
      radiusY: root.ringRadius
      startAngle: -90
      sweepAngle: 90
    }
  }

  RotationAnimator on rotation {
    from: 0
    to: 360
    duration: Theme.lockSpinnerTurn
    loops: Animation.Infinite
    running: root.running && root.visible && !Theme.reduceMotion
  }
}
