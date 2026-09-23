import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// A volume row: the slider plus the mute button that sit beside every volume readout.
// `node` is the PipeWire node driving it (a sink or a source, or null when none is up).
Item {
  id: root

  property var node: null
  property string accessibleName: ""
  property string muteAccessibleName: "Mute"

  // Rows without a mute control: the slider then takes the full width.
  property bool showMute: true

  readonly property var audio: root.node !== null && root.node.audio ? root.node.audio : null

  readonly property bool muted: root.audio !== null && root.audio.muted

  readonly property string glyph: Volume.glyph(root.node)

  implicitHeight: Theme.controlSliderHeight

  BigSlider {
    width: root.showMute ? root.width - Theme.controlSliderHeight - 10 : root.width
    height: parent.height
    accessibleName: root.accessibleName
    glyph: root.glyph
    value: root.audio ? root.audio.volume : 0
    dimmed: root.muted
    onMoved: function (v) {
      if (root.audio) {
        root.audio.muted = false;
        root.audio.volume = v;
      }
    }
  }

  MuteButton {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    visible: root.showMute
    accessibleName: root.muteAccessibleName
    muted: root.muted
    glyph: root.glyph
    onToggled: if (root.audio)
      root.audio.muted = !root.audio.muted
  }
}
