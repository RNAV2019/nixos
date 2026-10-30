import QtQuick
import qs.Commons

// The 8 px track under a card's readout: `surfaceRaised`, filled to `fraction` in the role colour.
// A depleting one is handed the remaining fraction.
Rectangle {
  id: root

  property real fraction: 0
  property color tint: Theme.accent

  height: Theme.activityTrackHeight
  radius: height / 2
  color: Theme.surfaceRaised

  Rectangle {
    width: Math.max(root.fraction > 0 ? root.height : 0, root.width * Theme.clamp01(root.fraction))
    height: parent.height
    radius: parent.radius
    color: root.tint
  }
}
