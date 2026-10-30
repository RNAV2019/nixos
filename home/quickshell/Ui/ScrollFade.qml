import QtQuick
import qs.Commons

// A capped list that scrolls fades out at its bottom edge while there is more below. Put it over
// the list, at its bottom; it takes no input.
Rectangle {
  id: root

  property real contentHeight: 0
  property real contentY: 0
  property real viewHeight: 0

  readonly property bool more: root.contentHeight > root.viewHeight + 1 && root.contentY + root.viewHeight < root.contentHeight - 1

  height: Theme.controlNotifFade
  opacity: root.more ? 1 : 0
  visible: opacity > 0

  Behavior on opacity {
    Morph {
      duration: Theme.morphState
    }
  }

  gradient: Gradient {
    GradientStop {
      position: 0
      color: Theme.withAlpha(Theme.surface, 0)
    }

    GradientStop {
      position: 1
      color: Theme.surface
    }
  }
}
