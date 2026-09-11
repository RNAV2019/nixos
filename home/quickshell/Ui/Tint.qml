import QtQuick
import qs.Commons

// The colour counterpart to Morph: same curve, at the state duration.
ColorAnimation {
  duration: Theme.morphState
  easing.type: Easing.Bezier
  easing.bezierCurve: Theme.morphCurve
}
