import QtQuick
import qs.Commons

Rectangle {
  id: root

  property real value: 0
  property color fillColor: Theme.accent

  implicitHeight: 6
  radius: height / 2
  color: Theme.overlay

  Rectangle {
    width: Math.max(0, Math.min(1, root.value)) * parent.width
    height: parent.height
    radius: parent.radius
    color: root.fillColor

    Behavior on width {
      NumberAnimation {
        duration: Theme.animFast
      }
    }
  }
}
