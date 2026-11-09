import QtQuick
import qs.Commons

// Colour never overshoots. A short ease-out keeps state changes legible without a brightness pulse.
// A surface that is opening sets its state at once (Bus.snapTints): a tint tweened under the
// first frames would still be running after the open, or the content morph, has landed.
ColorAnimation {
  duration: Bus.snapTints ? 0 : Theme.duration(Theme.tintFade)
  easing.type: Easing.OutQuad
}
