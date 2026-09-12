import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string placeholder: ""
  property bool echoPassword: true
  property string accessibleName: ""
  property alias text: input.text
  property alias inputItem: input
  signal accepted(string text)
  signal cancelled

  implicitHeight: 30
  radius: Theme.panelRowRadius
  color: Theme.withAlpha(Theme.text, Theme.fillNormal)
  border.width: 1
  border.color: input.activeFocus ? Theme.withAlpha(Theme.accent, Theme.borderSelected) : Theme.withAlpha(Theme.overlay, Theme.borderNormal)

  Accessible.role: Accessible.EditableText
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : (root.placeholder !== "" ? root.placeholder : "Text input")
  Accessible.description: root.echoPassword ? "Password" : ""
  Accessible.editable: true
  Accessible.passwordEdit: root.echoPassword
  Accessible.focusable: true
  Accessible.focused: input.activeFocus

  Behavior on border.color {
    Tint {}
  }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: Theme.panelRowInset
    anchors.rightMargin: Theme.panelRowInset
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.fontSize
    echoMode: root.echoPassword ? TextInput.Password : TextInput.Normal
    activeFocusOnTab: true
    selectByMouse: true
    selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
    clip: true

    // Keep Escape local to an editing field instead of losing it when TextInput owns focus.
    Keys.onPressed: function (event) {
      if (event.key === Qt.Key_Escape) {
        root.cancelled();
        event.accepted = true;
      }
    }

    Accessible.ignored: true

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
