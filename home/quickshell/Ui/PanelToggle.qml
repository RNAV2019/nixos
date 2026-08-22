import QtQuick
import qs.Commons

Rectangle {
  id: root

  property bool checked: false
  property bool enabled: true
  signal toggled(bool checked)

  implicitWidth: 34
  implicitHeight: 18
  radius: height / 2
  color: root.checked ? Theme.accent : Theme.overlay
  opacity: root.enabled ? 1 : 0.4

  Behavior on color {
    ColorAnimation {
      duration: Theme.animFast
    }
  }

  Rectangle {
    width: 14
    height: 14
    radius: width / 2
    color: root.checked ? Theme.base : Theme.muted
    anchors.verticalCenter: parent.verticalCenter
    x: root.checked ? parent.width - width - 2 : 2

    Behavior on x {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Easing.InOutQuad
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
