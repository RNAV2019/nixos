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
    font.family: Theme.uiFont
    font.pixelSize: Theme.fontSize
  }

  Text {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.value
    color: root.valueColor
    // Readouts stay monospaced so a changing value does not shuffle the row.
    font.family: Theme.monoFont
    font.pixelSize: Theme.fontSize
  }
}
