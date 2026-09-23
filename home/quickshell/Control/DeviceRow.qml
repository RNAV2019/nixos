import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string glyph: ""
  property string label: ""
  property string sublabel: ""
  property bool selected: false
  property bool showCheck: false
  property string accessibleName: ""

  default property alias actions: slot.data

  signal clicked

  readonly property bool hovered: hover.containsMouse
  readonly property bool pressed: hover.pressed

  readonly property color ink: selected ? Theme.inkOnAccent : Theme.inkPrimary

  implicitHeight: Theme.controlRowHeight
  radius: Theme.controlRowRadius

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.label
  Accessible.description: root.sublabel
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.clicked()

  color: {
    if (selected)
      return Theme.accent;
      return Theme.withAlpha(hovered ? Theme.highlightMed : Theme.surfaceSubtle, 0.9);
  }

  scale: pressed ? Theme.pressScale : 1

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
    onPressed: root.forceActiveFocus()
    onClicked: root.clicked()
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.clicked();
      event.accepted = true;
    }
  }

  Text {
    id: icon

    x: Theme.controlRowInset
    y: (parent.height - height) / 2
    visible: root.glyph !== ""
    text: root.glyph
    color: root.selected ? Theme.inkOnAccent : Theme.inkSecondary
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlTileGlyphSize
  }

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
    color: root.selected ? Theme.withAlpha(Theme.inkOnAccent, 0.72) : Theme.inkTertiary
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
    opacity: visible ? 1 : 0
    scale: visible ? 1 : 0.5
    text: Icons.check
    color: Theme.inkOnAccent
    font.family: Theme.iconFont
    font.pixelSize: 16

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.duration(Theme.morphState)
        easing.type: Easing.OutCubic
      }
    }

    Behavior on scale {
      Morph { duration: Theme.morphState }
    }
  }
}
