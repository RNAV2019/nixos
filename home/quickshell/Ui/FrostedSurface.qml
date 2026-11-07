import QtQuick
import Quickshell
import qs.Commons

// A floating opaque surface with the shell's shared fill and drop shadow.
Item {
  id: root

  // Defaults to the stadium. Callers pass min(height / 2, r) rather than animating it;
  // see Bar/Island.qml.
  property real surfaceRadius: height / 2
  property real screenOffsetX: 0
  property real screenOffsetY: 0

  // Where contents are laid out at final size and revealed as the pill grows; a shader crops
  // them to the card (Shaders/roundedclip.frag).
  property bool clipContent: false

  // Ground and contents fade separately during handoff, so the old panel's text is gone
  // before its surface.
  property real backdropOpacity: 1
  property real contentOpacity: 1

  // The drop shadow (Ui/DropShadow.qml): off for a surface flush with the screen edge.
  property bool shadowEnabled: true
  property real shadowStrength: Theme.surfaceShadowAlpha

  default property alias content: contentHolder.data

  // The box the contents are laid out in.
  readonly property Item contentBox: contentHolder

  // The shut pill and the like: sized to the surface, not to the contents' box.
  property alias fillData: fillHolder.data

  // The size the contents are laid out at, which is the open size. Set, the contents sit in a
  // box of exactly this size at (contentLeft, contentTop) in the parent's coordinates, however
  // big the card is just now. Left at 0, they fill the card.
  property real contentWidth: 0
  property real contentHeight: 0
  property real contentLeft: x + (width - contentWidth) / 2
  property real contentTop: y

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

  // Floats on the shell's drop shadow rather than an outline; it fades with the ground.
  DropShadow {
    radius: root.surfaceRadius
    strength: root.shadowStrength
    pixelRatio: root.pixelRatio
    opacity: root.backdropOpacity
    visible: root.shadowEnabled && root.backdropOpacity > 0 && root.width > 0 && root.height > 0
  }

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

  // Fills the surface under the contents and fades with them; the shut pill carried over
  // lives here, since it is the surface's own size and needs no fixed box.
  Item {
    id: fillHolder

    anchors.fill: parent
    opacity: root.contentOpacity
    visible: opacity > 0
  }

  // The contents' own box. Clipping, it is the open size and never changes during a morph: the
  // contents are laid out in it once, and the card uncovers them as it grows, so what is drawn
  // stays put on screen rather than riding an edge. A shader crops the texture it renders to
  // the card's rounded rectangle, so nothing is allocated per frame. Not clipping, or with no
  // open size, it simply fills the surface.
  Item {
    id: contentHolder

    readonly property bool boxed: root.clipContent && root.contentWidth > 0 && root.contentHeight > 0

    x: boxed ? root.snap(root.contentLeft) - root.x : 0
    y: boxed ? root.snap(root.contentTop) - root.y : 0
    width: boxed ? root.snap(root.contentWidth) : root.width
    height: boxed ? root.snap(root.contentHeight) : root.height
    opacity: root.clipContent ? 1 : root.contentOpacity
    visible: opacity > 0
  }

  ShaderEffectSource {
    id: contentTexture

    // 1:1 with the device pixels, so a settled card shows the contents exactly as drawn.
    textureSize: Qt.size(Math.round(contentHolder.width * root.pixelRatio), Math.round(contentHolder.height * root.pixelRatio))
    // Hidden (a parked window), no texture is held: nine idle panels would keep nine open-size ones.
    sourceItem: root.clipContent && root.visible ? contentHolder : null
    hideSource: root.clipContent
    live: true
    smooth: false
    visible: false
  }

  ShaderEffect {
    // Where the box sits is where the contents are; the card is cut out of it.
    x: contentHolder.x
    y: contentHolder.y
    width: contentHolder.width
    height: contentHolder.height
    visible: root.clipContent && root.contentOpacity > 0
    opacity: root.contentOpacity

    property variant source: contentTexture
    property size boxSize: Qt.size(root.width, root.height)
    property point boxOrigin: Qt.point(-contentHolder.x, -contentHolder.y)
    property size itemSize: Qt.size(width, height)
    property real radius: root.surfaceRadius
    property real aa: 1 / root.pixelRatio

    fragmentShader: Qt.resolvedUrl("../Shaders/roundedclip.frag.qsb")
  }
}
