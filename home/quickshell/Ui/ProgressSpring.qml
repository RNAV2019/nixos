import QtQuick
import qs.Commons

// A MorphSpring for a 0..1 progress (a reveal, a fade, a slide fraction): the island's pace and
// its damping (Theme.morphDamping, 0.9: about 0.15% past the end, then settled), solved per frame.
// Use it as `ProgressSpring { target: shown ? 1 : 0 }` and
// read `value`; the epsilon is sized for a unit range, not pixels.
MorphSpring {
  epsilon: 0.001
  omega: Theme.morphOmega
}
