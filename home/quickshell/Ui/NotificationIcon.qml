import QtQuick
import QtQuick.Effects

// A sender's icon in a notification avatar. An app's own icon keeps its colours; a custom
// override is a glyph whose alpha masks the avatar's accent, so it follows the theme.
Item {
  id: root

  property string source
  property bool tinted: false
  property color tint

  // Whether anything is drawn; the avatar shows its letter otherwise.
  readonly property bool shown: source !== "" && icon.status === Image.Ready

  Image {
    id: icon

    anchors.fill: parent
    source: root.source
    sourceSize.width: width * 3
    sourceSize.height: height * 3
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    visible: root.shown && !root.tinted
    layer.enabled: root.tinted
  }

  Rectangle {
    id: ink

    anchors.fill: parent
    color: root.tint
    visible: false
    layer.enabled: true
  }

  // MultiEffect widens the threshold by the spread, so 0.5 with a spread of 1 ramps across
  // alpha 0..1, keeping the glyph's edges and half-tones soft instead of cutting them hard.
  MultiEffect {
    anchors.fill: parent
    visible: root.shown && root.tinted
    source: ink
    maskEnabled: true
    maskSource: icon
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }
}
