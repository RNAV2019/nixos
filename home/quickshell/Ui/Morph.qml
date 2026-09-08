import QtQuick
import qs.Commons

// The one animation every surface morph uses. See Theme.morphCurve for why
// this is a fitted bezier rather than a SpringAnimation.
//
// Use it inside a Behavior:
//
//   Behavior on implicitWidth {
//     Morph {}
//   }
NumberAnimation {
  duration: Theme.morphDuration
  easing.type: Easing.Bezier
  easing.bezierCurve: Theme.morphCurve
}
