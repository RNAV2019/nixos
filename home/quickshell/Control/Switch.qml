import QtQuick
import qs.Commons

// The radio switch a sub-view header carries. It is the same on/off statement
// the tiles make with their fill, in the one place a tile is not available.
Rectangle {
  id: root

  property bool checked: false
  // Not `enabled`: that name belongs to Item, and shadowing it would leave the
  // switch drawing one state while the input layer believed another.
  property bool interactive: true

  signal toggled(bool value)

  implicitWidth: 46
  implicitHeight: 26
  radius: height / 2

  opacity: interactive ? 1 : 0.4
  color: checked ? Theme.accent : Theme.withAlpha(Theme.highlightMed, 0.9)

  Behavior on color {
    ColorAnimation {
      duration: Theme.morphToggle
    }
  }

  Rectangle {
    y: 3
    x: root.checked ? root.width - width - 3 : 3
    width: root.height - 6
    height: width
    radius: height / 2
    color: root.checked ? Theme.base : Theme.text

    Behavior on x {
      NumberAnimation {
        duration: Theme.morphToggle
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.morphCurve
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.interactive
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
