import QtQuick
import qs.Commons
import qs.Ui

// A row in a control-centre sub-view: a network, an audio device, a headset.
//
// The row is a pill on the same 46 px height the tiles are built from, and it
// says what it is with the same accent fill they use, so a connected device and
// an enabled toggle read as the same state.
Rectangle {
  id: root

  property string glyph: ""
  property string label: ""
  property string sublabel: ""
  property bool selected: false
  property bool showCheck: false

  default property alias actions: slot.data

  signal clicked

  readonly property bool hovered: hover.containsMouse
  readonly property bool pressed: hover.pressed

  readonly property color ink: selected ? Theme.base : Theme.text

  implicitHeight: Theme.controlRowHeight
  radius: Theme.controlRowRadius

  color: {
    if (selected)
      return Theme.accent;
    return Theme.withAlpha(hovered ? Theme.highlightMed : Theme.highlightLow, 0.9);
  }

  scale: pressed ? 0.97 : 1

  Behavior on scale {
    Morph { duration: Theme.morphState }
  }

  Behavior on color {
    Tint {}
  }

  MouseArea {
    id: hover

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  Text {
    id: icon

    x: Theme.controlRowInset
    y: (parent.height - height) / 2
    visible: root.glyph !== ""
    text: root.glyph
    color: root.selected ? Theme.base : Theme.subtle
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlTileGlyphSize
  }

  // One line is centred; two lines sit either side of the centre line, which is
  // what keeps a row with a subtitle the same height as one without.
  Text {
    id: name

    x: icon.visible ? icon.x + 30 : Theme.controlRowInset + 6
    y: root.sublabel !== "" ? parent.height / 2 - 17 : (parent.height - height) / 2
    width: Math.max(0, slot.x - x - 12)
    text: root.label
    color: root.ink
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize
    font.weight: root.sublabel !== "" ? Theme.weightSemi : Theme.weightRegular
    elide: Text.ElideRight
  }

  Text {
    x: name.x
    y: parent.height / 2 + 1
    width: name.width
    visible: root.sublabel !== ""
    text: root.sublabel
    color: root.selected ? Theme.withAlpha(Theme.base, 0.72) : Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileSubSize
    elide: Text.ElideRight
  }

  Row {
    id: slot

    anchors.right: check.visible ? check.left : parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    layoutDirection: Qt.RightToLeft
    spacing: 6
  }

  Text {
    id: check

    anchors.right: parent.right
    anchors.rightMargin: Theme.controlRowInset
    anchors.verticalCenter: parent.verticalCenter
    visible: root.showCheck && root.selected
    text: Icons.check
    color: Theme.base
    font.family: Theme.iconFont
    font.pixelSize: 16
  }
}
