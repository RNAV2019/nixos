import QtQuick
import qs.Commons

// The shared non-spatial transition. Spatial surfaces use SurfaceSpring so retargeting preserves
// velocity; this component is for small state changes and legacy content transitions.
NumberAnimation {
  duration: Theme.duration(Theme.morphSurface)
  easing.type: Easing.OutCubic
}
