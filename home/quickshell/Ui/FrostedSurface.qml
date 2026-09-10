import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons

// A floating surface with the shell's shared tint and compositor blur. Lower
// shell surfaces are hidden by their owners during handoff so only the desktop
// can show through this surface.
Item {
  id: root

  // Defaults to the stadium. Callers that want a flatter corner pass their own
  // radius, but they pass it through min(height / 2, r) rather than animating
  // it, so a short surface is always fully round; see Bar/Island.qml.
  property real surfaceRadius: height / 2
  property real screenOffsetX: 0
  property real screenOffsetY: 0

  // Clip the contents to the pill. A surface whose contents are laid out at
  // their final size and revealed as it grows needs this; one whose contents
  // always fit does not, and should not pay for the extra layer.
  property bool clipContent: false

  default property alias content: contentHolder.data

  // The surface stack, masked to the pill radius in one pass at the end.
  Item {
    id: frost

    anchors.fill: parent
    clip: true

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

  // A hairline that separates the surface from a wallpaper of the same ink.
  Rectangle {
    anchors.fill: parent
    radius: root.surfaceRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.withAlpha(Theme.surfaceBorder, Theme.surfaceBorderAlpha)
  }

  // The layer's texture is only as big as this item, so anything the contents
  // place outside the pill is dropped before the mask even runs; the mask is
  // what keeps the rounded corners honest.
  Item {
    id: contentHolder

    anchors.fill: parent
    layer.enabled: root.clipContent
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }
  }
}
