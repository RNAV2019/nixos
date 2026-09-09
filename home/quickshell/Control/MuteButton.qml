import QtQuick
import qs.Commons

// The round badge beside a device slider. Muted it goes red, because mute is
// the one audio state worth spotting from across the panel.
Rectangle {
  id: root

  property bool muted: false
  property string glyph: ""

  signal toggled

  implicitWidth: Theme.controlSliderHeight
  implicitHeight: Theme.controlSliderHeight
  radius: height / 2

  color: {
    if (muted)
      return Theme.withAlpha(Theme.urgent, hover.containsMouse ? 0.95 : 0.8);
    return Theme.withAlpha(hover.containsMouse ? Theme.highlightMed : Theme.highlightLow, 0.9);
  }

  Text {
    anchors.centerIn: parent
    text: root.glyph
    color: root.muted ? Theme.base : Theme.subtle
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlTileGlyphSize
  }

  MouseArea {
    id: hover

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
