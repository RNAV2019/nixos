import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string placeholder: ""
  property bool echoPassword: true
  property alias text: input.text
  property alias inputItem: input
  signal accepted(string text)

  implicitHeight: 30
  radius: Theme.panelRowRadius
  color: Theme.withAlpha(Theme.text, Theme.fillNormal)
  border.width: 1
  border.color: input.activeFocus ? Theme.withAlpha(Theme.accent, Theme.borderSelected) : Theme.withAlpha(Theme.overlay, Theme.borderNormal)

  Behavior on border.color {
    ColorAnimation {
      duration: Theme.animFast
    }
  }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: Theme.panelRowInset
    anchors.rightMargin: Theme.panelRowInset
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    echoMode: root.echoPassword ? TextInput.Password : TextInput.Normal
    selectByMouse: true
    selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
    clip: true

    onAccepted: root.accepted(text)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.placeholder
      color: Theme.muted
      font: input.font
      visible: input.text.length === 0 && !input.activeFocus
    }
  }
}
