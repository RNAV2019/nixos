import QtQuick
import qs.Commons

// A shorter, non-bouncy response for pressed states, selection indicators and small controls.
SpringAnimation {
  spring: Theme.reduceMotion ? 5 : Theme.microSpring
  damping: Theme.reduceMotion ? 1 : Theme.microDamping
  mass: Theme.microMass
  epsilon: Theme.microEpsilon
}
