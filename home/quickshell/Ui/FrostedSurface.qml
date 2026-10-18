import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons

// A floating opaque surface with the shell's shared fill.
Item {
  id: root

  // Defaults to the stadium. Callers pass min(height / 2, r) rather than animating it;
  // see Bar/Island.qml.
  property real surfaceRadius: height / 2
  property real screenOffsetX: 0
  property real screenOffsetY: 0

  // Only needed where contents are laid out at final size and revealed as the pill grows.
  property bool clipContent: false

  // Ground and contents fade separately during handoff, so the old panel's text is gone
  // before its surface.
  property real backdropOpacity: 1
  property real contentOpacity: 1

  default property alias content: contentHolder.data

  // At a fractional scale most logical coordinates fall between device pixels, and the
  // clipContent layer is then resampled, softening every glyph in it. Size lands on the
  // pixel grid here; callers place the surface with snap().
  //
  // The ratio is held, not read live: an unmapped window reports none, and falling back to 1
  // re-rounded every size on the way out, which flipped a surface's showing test, re-mapped it
  // and looped the width binding through the window it lives in.
  readonly property real liveRatio: QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 0
  property real pixelRatio: 1

  // Taken after the binding pass that changed it, never inside one: a window made by a size
  // test (showing -> visible) must not re-round the size that test is reading.
  function adoptRatio() {
    if (liveRatio > 0 && liveRatio !== pixelRatio)
      pixelRatio = liveRatio;
  }

  onLiveRatioChanged: Qt.callLater(root.adoptRatio)
  Component.onCompleted: adoptRatio()

  function snap(v) {
    return Math.round(v * pixelRatio) / pixelRatio;
  }

  width: snap(implicitWidth)
  height: snap(implicitHeight)

  Item {
    id: frost

    anchors.fill: parent
    clip: true
    visible: opacity > 0
    opacity: root.backdropOpacity

    Rectangle {
      anchors.fill: parent
      radius: root.surfaceRadius
      color: Theme.surface
    }
  }

  // The opaque fill makes contrast deterministic; this outline keeps the material legible
  // against a near-black desktop. Intentionally quieter than a glow.
  Rectangle {
    anchors.fill: parent
    radius: root.surfaceRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.surfaceOutline
    opacity: root.backdropOpacity
    visible: opacity > 0
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
