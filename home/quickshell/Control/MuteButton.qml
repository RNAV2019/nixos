import QtQuick
import qs.Commons
import qs.Ui

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

  scale: hover.pressed ? 0.97 : 1

  Behavior on color {
    Tint {}
  }

  Behavior on scale {
    Morph { duration: Theme.morphState }
  }

  Text {
    anchors.centerIn: parent
    text: root.glyph
    color: root.muted ? Theme.inkOnDanger : Theme.inkSecondary
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
