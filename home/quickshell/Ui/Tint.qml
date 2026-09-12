import QtQuick
import qs.Commons

// Colour never overshoots. A short ease-out keeps state changes legible without a brightness pulse.
ColorAnimation {
  duration: Theme.duration(Theme.morphState)
  easing.type: Easing.OutQuad
}
