import QtQuick
import qs.Commons

// A MorphSpring for a 0..1 progress (a reveal, a fade, a slide fraction): the island's pace,
// critically damped, solved per frame. Use it as `ProgressSpring { target: shown ? 1 : 0 }` and
// read `value`; the epsilon is sized for a unit range, not pixels.
MorphSpring {
  epsilon: 0.001
  omega: Theme.morphOmega
}
