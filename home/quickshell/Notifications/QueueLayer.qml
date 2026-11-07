import QtQuick
import qs.Commons
import qs.Ui

// A toast waiting behind the card, showing only the curve of its bottom edge.
Item {
  id: layer

  required property var host
  // 1 is the next toast, 2 the one after.
  required property int depth

  readonly property bool shown: layer.host.open && layer.host.origin.presented && layer.host.queued >= layer.depth

  parent: layer.host.contentItem
  z: -layer.depth
  x: layer.host.surface.x
  y: layer.host.surface.snap(layer.host.surface.y + layer.host.surface.height)
  width: layer.host.surface.width
  height: Theme.notifQueuePeek * (Theme.notifQueueLayers + 1)
  clip: true
  opacity: layer.shown ? 1 : 0
  visible: opacity > 0

  Behavior on opacity {
    Morph {
      duration: Theme.morphState
    }
  }

  Rectangle {
    x: Theme.notifQueueInset * layer.depth
    y: Theme.notifQueuePeek * layer.depth + layer.host.rise - height
    width: layer.width - x * 2
    height: Theme.notifRadius * 2
    radius: Theme.notifRadius
    // No outline: lifted a step off the ground, so a peeking card still reads as its own card
    // against the one in front, and floating on the shadow like every surface.
    color: Qt.tint(Theme.surface, Theme.lift(Theme.liftTile))

    DropShadow {
      radius: parent.radius
    }
  }
}
