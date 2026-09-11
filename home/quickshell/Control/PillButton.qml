import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string label: ""
  property bool destructive: false
  // Set on rows that are themselves accent filled.
  property bool onAccent: false

  // Rows that only reveal an action under the pointer set this. The button is always
  // laid out and tracks its own hover; only its paint and clicks are withheld. It
  // cannot be `visible`: hiding would hand the hover back to the row and flicker.
  property bool revealed: true

  readonly property bool hovered: hover.containsMouse

  signal clicked

  readonly property color ink: {
    if (onAccent)
      return Theme.base;
    return destructive ? Theme.urgent : Theme.accent;
  }

  implicitWidth: text.implicitWidth + 24
  implicitHeight: 26
  radius: height / 2

  opacity: revealed ? 1 : 0

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.morphState
    }
  }

  color: {
    if (onAccent)
      return Theme.withAlpha(Theme.base, hover.containsMouse ? 0.24 : 0.14);
    return Theme.withAlpha(destructive ? Theme.urgent : Theme.accent, hover.containsMouse ? 0.2 : 0);
  }

  scale: hover.pressed ? 0.97 : 1

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
    onClicked: if (root.revealed)
      root.clicked()
  }
}
