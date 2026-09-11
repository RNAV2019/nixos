import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons

// A floating surface with the shell's shared tint and compositor blur.
Item {
  id: root

  // Defaults to the stadium. Callers pass their own radius through min(height / 2, r)
  // rather than animating it; see Bar/Island.qml.
  property real surfaceRadius: height / 2
  property real screenOffsetX: 0
  property real screenOffsetY: 0

  // Only needed where contents are laid out at final size and revealed as the pill grows.
  property bool clipContent: false

  // Ground and contents fade separately: the taker's blur samples what is behind it,
  // so the old panel's text must be gone well before its ground is.
  property real backdropOpacity: 1
  property real contentOpacity: 1

  default property alias content: contentHolder.data

  Item {
    id: frost

    anchors.fill: parent
    clip: true
    opacity: root.backdropOpacity
    visible: opacity > 0

    Rectangle {
      anchors.fill: parent
      radius: root.surfaceRadius
      color: Theme.withAlpha(Theme.surfaceTint, Theme.surfaceTintAlpha)
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: root.surfaceRadius
      color: "black"
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.surfaceRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.withAlpha(Theme.surfaceBorder, Theme.surfaceBorderAlpha)
    opacity: root.backdropOpacity
    visible: opacity > 0
  }

  // The layer's texture is only as big as this item, so contents outside the pill are
  // dropped before the mask runs.
  Item {
    id: contentHolder

    anchors.fill: parent
    opacity: root.contentOpacity
    visible: opacity > 0
    layer.enabled: root.clipContent
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }
  }
}
