import QtQuick
import qs.Commons

Item {
  id: root

  property string label: ""
  property string value: ""
  property color valueColor: Theme.text

  implicitHeight: 22

  Text {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Theme.subtle
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
  }

  Text {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.value
    color: root.valueColor
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
  }
}
