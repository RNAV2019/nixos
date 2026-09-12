import QtQuick
import qs.Commons

// Shared spatial spring for surfaces and other geometry that must preserve velocity when its
// target changes. Opacity and colour intentionally use the non-spring animations instead.
SpringAnimation {
  spring: Theme.reduceMotion ? 5 : Theme.surfaceSpring
  damping: Theme.reduceMotion ? 1 : Theme.surfaceDamping
  mass: Theme.surfaceMass
  epsilon: Theme.surfaceEpsilon
}
