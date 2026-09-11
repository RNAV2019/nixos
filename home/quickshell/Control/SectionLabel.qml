import QtQuick
import qs.Commons

Item {
  id: root

  property string title: ""
  property string note: ""

  implicitHeight: Theme.controlSectionHeight

  Text {
    y: parent.height - height - 4
    text: root.title
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlSectionSize
    font.weight: Theme.weightMedium
  }

  Text {
    x: parent.width - width
    y: parent.height - height - 4
    visible: root.note !== ""
    text: root.note
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlSectionSize
    font.weight: Theme.weightMedium
  }
}
