import QtQuick
import QtQuick.Shapes
import qs.Commons

// A full circle's progress: a faint track ring and an arc over it from twelve o'clock, clockwise,
// `value` of the way round (0..1). Both strokes sit inside `size`, the ring inset by half a
// stroke, as Ui/Spinner.qml draws its ring. Sized and inked by the caller; with `animated` the
// arc eases to each new value rather than jumping to it.
Shape {
  id: root

  property real size: Theme.lockSpinnerSize
  property real stroke: 2
  // Set to place the ring off the default inset, inside a larger box.
  property real ringRadius: (size - stroke) / 2

  property real value: 0
  property bool animated: false
  property int duration: Theme.morphState

  property color trackColor: Theme.withAlpha(Theme.inkTertiary, 0.35)
  property color fillColor: Theme.accentFill
  property bool roundCap: true

  // What the arc is drawn at: `value` itself, or while `animated` the eased reading.
  property real shown: Theme.clamp01(value)

  Behavior on shown {
    enabled: root.animated && !Theme.reduceMotion

    Morph {
      duration: root.duration
    }
  }

  implicitWidth: size
  implicitHeight: size
  antialiasing: true
  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    fillColor: "transparent"
    strokeColor: root.trackColor
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
    strokeColor: root.fillColor
    strokeWidth: root.stroke
    capStyle: root.roundCap ? ShapePath.RoundCap : ShapePath.FlatCap

    PathAngleArc {
      centerX: root.width / 2
      centerY: root.height / 2
      radiusX: root.ringRadius
      radiusY: root.ringRadius
      startAngle: -90
      sweepAngle: 360 * root.shown
    }
  }
}
