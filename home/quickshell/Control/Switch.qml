import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property bool checked: false
  property string accessibleName: ""
  // Not `enabled`: Item already owns that name.
  property bool interactive: true
  readonly property bool pressed: mouse.pressed

  signal toggled(bool value)

  implicitWidth: 46
  implicitHeight: 26
  radius: height / 2

  activeFocusOnTab: true
  Accessible.role: Accessible.CheckBox
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : "Switch"
  Accessible.checked: root.checked
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onToggleAction: if (root.interactive)
    root.toggled(!root.checked)

  opacity: interactive ? 1 : 0.4
  color: checked ? Theme.accentFill : Theme.withAlpha(Theme.separator, 0.9)
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
    color: root.checked ? Theme.inkOnAccent : Theme.inkPrimary

    Behavior on x {
      enabled: !Theme.reduceMotion

      MicroSpring {}
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.interactive
    cursorShape: Qt.PointingHandCursor
    onPressed: root.forceActiveFocus()
    onClicked: root.toggled(!root.checked)
  }

  Keys.onPressed: function (event) {
    if ((event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.interactive) {
      root.toggled(!root.checked);
      event.accepted = true;
    }
  }
}
