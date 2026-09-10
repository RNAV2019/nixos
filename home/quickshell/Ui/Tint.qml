import QtQuick
import qs.Commons

// The colour counterpart to Morph.qml, and the reason it exists.
//
// Shape in this shell always travelled on the fitted spring, but colour was
// written out as a bare ColorAnimation at eight of its twelve call sites, and
// a bare ColorAnimation is linear. A tile whose fill ramps at a constant rate
// inside a surface whose edge accelerates and arrives does not read as the
// same shell moving; it reads as two different ones. Seven more places changed
// colour on hover with no Behavior at all and simply snapped.
//
// So colour gets a named animation of its own, on the same curve, at the state
// duration. Use it inside a Behavior:
//
//   Behavior on color {
//     Tint {}
//   }
ColorAnimation {
  duration: Theme.morphState
  easing.type: Easing.Bezier
  easing.bezierCurve: Theme.morphCurve
}
