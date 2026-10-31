import QtQuick
import qs.Commons

// A single-line text field. Panel sits on a faint ground with an outline that takes the accent
// while it has focus; Bare is the text alone, for a field that is the whole of its row (the
// launcher's search). The caret is an accent bar in both.
Item {
  id: root

  enum Kind {
    Panel,
    Bare
  }

  property int kind: TextField.Panel
  property string placeholder: ""
  property bool echoPassword: false
  property string accessibleName: ""
  property alias text: input.text
  property alias selectedText: input.selectedText
  property alias inputItem: input

  readonly property bool bare: kind === TextField.Bare

  signal accepted(string text)
  signal cancelled
  // Every key the field sees, before it does: set `event.accepted` to keep the field from it.
  signal keyPressed(var event)

  implicitHeight: bare ? input.implicitHeight : Theme.textFieldHeight
  opacity: root.enabled ? 1 : Theme.disabledAlpha

  Accessible.role: Accessible.EditableText
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : (root.placeholder !== "" ? root.placeholder : "Text input")
  Accessible.description: root.echoPassword ? "Password" : ""
  Accessible.editable: true
  Accessible.passwordEdit: root.echoPassword
  Accessible.focusable: true
  Accessible.focused: input.activeFocus

  Rectangle {
    anchors.fill: parent
    visible: !root.bare
    radius: Theme.panelRowRadius
    color: Theme.withAlpha(Theme.text, Theme.fillNormal)
    border.width: 1
    border.color: input.activeFocus ? Theme.withAlpha(Theme.accent, Theme.borderSelected) : Theme.withAlpha(Theme.overlay, Theme.borderNormal)

    Behavior on border.color {
      Tint {}
    }
  }

  TextInput {
    id: input

    anchors.fill: parent
    anchors.leftMargin: root.bare ? 0 : Theme.panelRowInset
    anchors.rightMargin: root.bare ? 0 : Theme.panelRowInset
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: root.bare ? Theme.launcherSearchSize : Theme.fontSize
    echoMode: root.echoPassword ? TextInput.Password : TextInput.Normal
    activeFocusOnTab: !root.bare
    selectByMouse: true
    selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
    clip: true

    cursorDelegate: Rectangle {
      width: 1.5
      radius: 0.75
      color: Theme.accent
    }

    // Keep Escape local to an editing field instead of losing it when TextInput owns focus.
    Keys.onPressed: function (event) {
      root.keyPressed(event);
      if (event.accepted)
        return;
      if (event.key === Qt.Key_Escape && !root.bare) {
        root.cancelled();
        event.accepted = true;
      }
    }

    Accessible.ignored: true

    onAccepted: root.accepted(text)

    Text {
      width: input.width
      anchors.verticalCenter: parent.verticalCenter
      text: root.placeholder
      color: Theme.muted
      elide: Text.ElideRight
      font: input.font
      // A bare field is always the one in focus, so its hint stays while it is empty.
      visible: input.text.length === 0 && (root.bare || !input.activeFocus)
    }
  }
}
