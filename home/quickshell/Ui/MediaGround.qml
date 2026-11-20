import QtQuick
import qs.Commons
import qs.Services

// The control centre's media card ground made of the playing track's cover, so the card carries
// on from the picture rather than fading it into a grey (Ryan, 2026-11-20). Lies over the card's
// own fill and under its CoverBleed, whose far end then fades the picture itself out
// (CoverBleed.fadesOut) onto this. Shaders/mediaground.frag draws it: blurred, dimmed with the
// cover when paused, and let down under the words only as far as every ink in `inks` needs to
// keep its contrast on it. With no cover there is nothing here (`presence`).
Item {
  id: root

  property string source: Media.artUrl
  property bool dimmed: Media.active && !Media.playing
  // "edge": the cover's right edge carried on across the card; "whole": the whole cover, blurred;
  // "solid": none of this, the card's own fill as before.
  property string mode: Theme.controlMediaGround
  readonly property bool active: mode !== "solid"
  // The CoverBleed this stands under, and where the words start.
  property real bleedWidth: 0
  property real columnLeft: 0
  // What is drawn on it, as [colour, alpha, contrast ratio]: an ink laid at that alpha must keep
  // that ratio against the ground under it.
  property var inks: []

  // How much of the card it covers: 0 with no cover, or with the mode "solid".
  readonly property real presence: active ? art.presence : 0
  readonly property bool whole: mode === "whole"

  // As the shader takes them: up to four inks, each sRGB with the alpha it is laid at, and the
  // ratio each must keep, with Theme.controlMediaInkMargin to spare.
  function inkAt(i) {
    if (i >= inks.length)
      return Qt.vector4d(0, 0, 0, 0);
    var c = inks[i][0];
    return Qt.vector4d(c.r, c.g, c.b, inks[i][1]);
  }

  function ratioAt(i) {
    return i < inks.length ? inks[i][2] + Theme.controlMediaInkMargin : 0;
  }

  // The paused dim, as CoverBleed's comes and goes.
  property real dim: dimmed ? Theme.coverPausedDim : 0

  Behavior on dim {
    Morph {
      duration: Theme.stateSwap
    }
  }

  opacity: presence
  visible: opacity > 0

  // The cover, small and cropped as the mode lays it out; a new one fades in over the last.
  ArtFade {
    id: art

    readonly property real span: root.whole ? root.width : root.bleedWidth
    readonly property real texels: root.whole ? Theme.controlMediaGroundTexelsWhole : Theme.controlMediaGroundTexels

    width: Math.max(1, Math.round(span * texels))
    height: Math.max(1, Math.round(root.height * texels))
    source: root.active ? root.source : ""
    sourceSize: Qt.size(Theme.controlMediaGroundDecode, Theme.controlMediaGroundDecode)
  }

  ShaderEffectSource {
    id: artTexture

    sourceItem: art
    hideSource: true
    smooth: true
    visible: false
  }

  ShaderEffect {
    anchors.fill: parent

    property var art: artTexture
    property size itemSize: Qt.size(width, height)
    property size bleedSize: Qt.size(Math.max(1, root.bleedWidth), Math.max(1, height))
    property real mode: root.whole ? 1 : 0
    property real edgeInset: Theme.controlMediaGroundEdgeInset
    property real blur: root.whole ? Theme.controlMediaGroundBlurWhole : Theme.controlMediaGroundBlurEdge
    property real dim: root.dim
    property vector4d ink0: root.inkAt(0)
    property vector4d ink1: root.inkAt(1)
    property vector4d ink2: root.inkAt(2)
    property vector4d ink3: root.inkAt(3)
    property vector4d ratios: Qt.vector4d(root.ratioAt(0), root.ratioAt(1), root.ratioAt(2), root.ratioAt(3))
    property real capFrom: root.bleedWidth * 0.42
    property real capTo: root.columnLeft

    fragmentShader: Qt.resolvedUrl("../Shaders/mediaground.frag.qsb")
  }
}
