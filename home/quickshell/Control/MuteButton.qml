import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property bool muted: false
  property string glyph: ""
  property string accessibleName: ""

  signal toggled

  implicitWidth: Theme.controlSliderHeight
  implicitHeight: Theme.controlSliderHeight
  radius: height / 2

  activeFocusOnTab: true

  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : "Mute"
  Accessible.checkable: true
  Accessible.checked: root.muted
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.toggled()

  color: {
    if (muted)
      return Theme.withAlpha(Theme.urgent, hover.containsMouse ? 0.95 : 0.8);
    return Theme.withAlpha(hover.containsMouse ? Theme.highlightMed : Theme.highlightLow, 0.9);
  }

  scale: hover.pressed ? Theme.pressScale : 1

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
    onPressed: root.forceActiveFocus()
    onClicked: root.toggled()
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.toggled();
      event.accepted = true;
    }
  }
}
