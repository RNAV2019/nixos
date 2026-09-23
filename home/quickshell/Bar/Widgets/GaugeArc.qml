import QtQuick
import QtQuick.Shapes
import qs.Commons

// One island-gauge ring: 240 degrees about a 48 px box, open at the bottom where the label
// sits. With `value` left at 1 it is the track.
ShapePath {
  id: arc

  property real radius: Theme.islandGaugeRadius
  property real value: 1

  strokeWidth: value > 0 ? 4 : 0
  capStyle: ShapePath.RoundCap
  fillColor: "transparent"

  PathAngleArc {
    centerX: Theme.islandGaugeSize / 2
    centerY: Theme.islandGaugeSize / 2
    radiusX: arc.radius
    radiusY: arc.radius
    startAngle: 150
    sweepAngle: 240 * Theme.clamp01(arc.value)

    Behavior on sweepAngle {
      NumberAnimation {
        duration: Theme.duration(Theme.morphState)
        easing.type: Easing.OutCubic
      }
    }
  }
}
