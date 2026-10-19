import QtQuick
import qs.Commons

// IconButton for the stroke icons (IconPaths): the same hover ink, press scale and invisible
// margin, drawn by StrokeIcon rather than a font glyph.
StrokeIcon {
  id: root

  property string accessibleName: ""

  property color baseColor: Theme.inkTertiary
  property color hoverColor: Theme.inkPrimary

  // Extra invisible margin around the icon, beyond its drawn size.
  property int hitSlop: 8

  signal clicked

  readonly property bool hovered: hover.containsMouse

  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleName
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.clicked()

  color: hover.containsMouse ? root.hoverColor : root.baseColor

  Behavior on color {
    Tint {}
  }

  scale: hover.pressed ? Theme.pressScale : 1

  Behavior on scale {
    Morph {
      duration: Theme.morphState
    }
  }

  MouseArea {
    id: hover

    anchors.fill: parent
    anchors.margins: -root.hitSlop
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: if (root.activeFocusOnTab)
      root.forceActiveFocus()
    onClicked: root.clicked()
  }
}
