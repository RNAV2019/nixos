import QtQuick
import qs.Commons

// The small action a row carries: Connect, Disconnect, Forget, Pair.
//
// Two weights. On an accent-filled row the button is drawn in the row's own
// ink, because accent on accent has nothing to separate it; everywhere else it
// is a bare accent label that gains a fill on hover.
Rectangle {
  id: root

  property string label: ""
  property bool destructive: false
  // Set on rows that are themselves accent filled.
  property bool onAccent: false

  // Rows that only reveal an action under the pointer set this. The button is
  // always laid out and always tracks its own hover; only its paint and its
  // clicks are withheld.
  //
  // It cannot be `visible`. The button sits on top of the row's own MouseArea,
  // so the moment the pointer crosses onto it the row stops being hovered - and
  // a button that hid itself on that would hand the hover straight back to the
  // row, be shown again, take the hover again, and flicker for as long as the
  // pointer sat on it. Publishing `hovered` is what breaks that loop: the caller
  // reveals on the row's hover or the button's own, so once the pointer is on
  // the button the button is what keeps it there.
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
      duration: Theme.animFast
    }
  }

  color: {
    if (onAccent)
      return Theme.withAlpha(Theme.base, hover.containsMouse ? 0.24 : 0.14);
    return Theme.withAlpha(destructive ? Theme.urgent : Theme.accent, hover.containsMouse ? 0.2 : 0);
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
