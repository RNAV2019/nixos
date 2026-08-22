import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Scope {
  id: root

  property bool open: false
  property int current: 0

  readonly property var actions: [
    {
      "label": "󰌾  Lock",
      "key": "l"
    },
    {
      "label": "󰜉  Reboot",
      "key": "r"
    },
    {
      "label": "󰐥  Shutdown",
      "key": "s"
    }
  ]

  function move(delta) {
    var n = root.actions.length;
    root.current = (root.current + delta + n) % n;
  }

  function run(index) {
    root.open = false;
    switch (index) {
    case 0:
      Bus.lockRequested();
      break;
    case 1:
      systemctl.command = ["systemctl", "reboot"];
      systemctl.running = true;
      break;
    case 2:
      systemctl.command = ["systemctl", "poweroff"];
      systemctl.running = true;
      break;
    }
  }

  onOpenChanged: {
    if (open)
      current = 0;
  }

  Process {
    id: systemctl
  }

  Connections {
    target: Bus

    function onSessionToggled() {
      root.open = !root.open;
    }
  }

  PanelWindow {
    id: window

    visible: root.open
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-session"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.base, 0.65)

      MouseArea {
        anchors.fill: parent
        onClicked: root.open = false
      }
    }

    Item {
      anchors.fill: parent
      focus: root.open

      Keys.onEscapePressed: root.open = false
      Keys.onUpPressed: root.move(-1)
      Keys.onDownPressed: root.move(1)
      Keys.onReturnPressed: root.run(root.current)
      Keys.onEnterPressed: root.run(root.current)

      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_K) {
          root.move(-1);
          event.accepted = true;
          return;
        }
        if (event.key === Qt.Key_J) {
          root.move(1);
          event.accepted = true;
          return;
        }
        for (var i = 0; i < root.actions.length; i++) {
          if (event.text === root.actions[i].key) {
            root.run(i);
            event.accepted = true;
            return;
          }
        }
      }

      Column {
        anchors.centerIn: parent
        spacing: Theme.spacingLg

        Repeater {
          model: root.actions

          Item {
            id: entry

            required property var modelData
            required property int index

            // Keep pointer and keyboard selection synchronized.
            readonly property bool active: root.current === entry.index

            width: 240
            height: 56

            Text {
              anchors.centerIn: parent
              text: entry.modelData.label
              color: entry.active ? Theme.love : Theme.muted
              font.family: Theme.fontFamily
              font.pixelSize: 20

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animFast
                }
              }
            }

            HoverHandler {
              id: hover
              cursorShape: Qt.PointingHandCursor
              onHoveredChanged: {
                if (hovered)
                  root.current = entry.index;
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.run(entry.index)
            }
          }
        }
      }
    }
  }
}
