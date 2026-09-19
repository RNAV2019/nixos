import QtQuick
import QtQuick.Shapes
import qs.Commons

// One ring of an island gauge: 240 degrees about a 48 px box, open at the bottom where the
// gauge's label sits. With `value` left at 1 it is the track.
ShapePath {
  id: arc

  property real radius: 21
  property real value: 1

  strokeWidth: value > 0 ? 4 : 0
  capStyle: ShapePath.RoundCap
  fillColor: "transparent"

  PathAngleArc {
    centerX: 24
    centerY: 24
    radiusX: arc.radius
    radiusY: arc.radius
    startAngle: 150
    sweepAngle: 240 * Math.max(0, Math.min(1, arc.value))

    Behavior on sweepAngle {
      NumberAnimation {
        duration: Theme.duration(Theme.morphState)
        easing.type: Easing.OutCubic
      }
    }
  }
}
