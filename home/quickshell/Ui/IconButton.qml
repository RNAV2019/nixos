import QtQuick
import qs.Commons

// The shared icon-only click target: a glyph with a hover tint, a press scale and an
// invisible margin so a small glyph keeps a comfortable hit area. `text` carries the
// glyph; colour comes from `baseColor`/`hoverColor` so callers keep their own palette.
Text {
  id: root

  property string accessibleName: ""

  property color baseColor: Theme.subtle
  property color hoverColor: Theme.text

  // Extra invisible margin around the glyph, beyond its drawn size.
  property int hitSlop: 8

  // A filled disc behind the glyph, for the media card's play button.
  property bool filled: false
  property color fillColor: Theme.withAlpha(Theme.text, 0.94)
  property color fillHoverColor: Theme.text
  property real fillSize: 0

  signal clicked

  readonly property bool hovered: hover.containsMouse

  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.text
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.clicked()

  color: hover.containsMouse ? root.hoverColor : root.baseColor

  Behavior on color {
    Tint {}
  }

  scale: hover.pressed ? Theme.pressScale : 1

  Behavior on scale {
    Morph { duration: Theme.morphState }
  }

  Rectangle {
    z: -1
    anchors.centerIn: parent
    visible: root.filled
    width: root.fillSize > 0 ? root.fillSize : root.implicitWidth + root.hitSlop * 2
    height: width
    radius: height / 2
    color: hover.containsMouse ? root.fillHoverColor : root.fillColor

    Behavior on color {
      Tint {}
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
