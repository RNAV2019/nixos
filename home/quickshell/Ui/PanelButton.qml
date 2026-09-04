import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string label: ""
  property bool destructive: false
  property bool enabled: true
  signal clicked

  implicitWidth: text.implicitWidth + 20
  implicitHeight: 26
  radius: Theme.panelRowRadius
  opacity: root.enabled ? 1 : 0.4

  color: hover.hovered ? Theme.withAlpha(root.destructive ? Theme.love : Theme.text, Theme.fillHover) : Theme.withAlpha(Theme.text, Theme.fillNormal)
  border.width: 1
  border.color: hover.hovered ? Theme.withAlpha(root.destructive ? Theme.love : Theme.text, Theme.borderHover) : Theme.withAlpha(Theme.overlay, Theme.borderNormal)

  Behavior on color {
    ColorAnimation {
      duration: Theme.animFast
    }
  }

  Text {
    id: text
    anchors.centerIn: parent
    text: root.label
    color: root.destructive ? Theme.love : Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.fontSize
    font.weight: Theme.weightMedium
  }

  HoverHandler {
    id: hover
    enabled: root.enabled
    cursorShape: Qt.PointingHandCursor
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.enabled
    onClicked: root.clicked()
  }
}
