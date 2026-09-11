import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property bool checked: false
  // Not `enabled`: Item already owns that name.
  property bool interactive: true
  readonly property bool pressed: mouse.pressed

  signal toggled(bool value)

  implicitWidth: 46
  implicitHeight: 26
  radius: height / 2

  opacity: interactive ? 1 : 0.4
  color: checked ? Theme.accent : Theme.withAlpha(Theme.highlightMed, 0.9)
  scale: pressed ? 0.97 : 1

  Behavior on color {
    Tint {}
  }

  Behavior on scale {
    Morph { duration: Theme.morphState }
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
        duration: Theme.morphState
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.morphCurve
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.interactive
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
