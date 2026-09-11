import QtQuick
import qs.Commons

// The shared surface-morph animation; see Theme.morphCurve.
NumberAnimation {
  duration: Theme.morphSurface
  easing.type: Easing.Bezier
  easing.bezierCurve: Theme.morphCurve
}
