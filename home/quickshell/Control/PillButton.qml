import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string label: ""
  property bool destructive: false
  // Set on rows that are themselves accent-filled.
  property bool onAccent: false
  property string accessibleName: ""

  // Reveal-under-pointer rows set this: the button stays laid out and tracks its own
  // hover; it cannot use `visible`, or the hover returns to the row and flickers.
  property bool revealed: true

  readonly property bool hovered: hover.containsMouse

  signal clicked

  readonly property color ink: {
    if (onAccent)
      return Theme.inkOnAccent;
    return destructive ? Theme.dangerFill : Theme.accentFill;
  }

  implicitWidth: text.implicitWidth + 24
  implicitHeight: 26
  radius: height / 2

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.label
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: if (root.revealed)
    root.clicked()

  opacity: revealed ? 1 : 0

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.morphState
    }
  }

  color: {
    if (onAccent)
      return Theme.withAlpha(Theme.inkOnAccent, hover.containsMouse ? 0.24 : 0.14);
    return Theme.withAlpha(destructive ? Theme.dangerFill : Theme.accentFill, hover.containsMouse ? 0.2 : 0);
  }

  scale: hover.pressed ? Theme.pressScale : 1

  Behavior on color {
    Tint {}
  }

  Behavior on scale {
    Morph { duration: Theme.morphState }
  }

  Text {
    id: text

    anchors.centerIn: parent
    text: root.label
    color: root.ink
    font.family: Theme.uiFont
    font.pixelSize: 12
    font.weight: Theme.weightMedium
  }

  MouseArea {
    id: hover

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.revealed ? Qt.PointingHandCursor : Qt.ArrowCursor
    onPressed: root.forceActiveFocus()
    onClicked: if (root.revealed)
      root.clicked()
  }

  Keys.onPressed: function (event) {
    if (root.revealed && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      root.clicked();
      event.accepted = true;
    }
  }
}
