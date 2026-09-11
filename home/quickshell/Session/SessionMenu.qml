import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power menu: the island grown into a card of tiles. Lock acts on the first press;
// the two that end the session arm first and commit only on a second press.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "session"
    openWidth: win.contentWidth
    openHeight: Theme.powerHeight
    openRadius: Theme.powerRadius

    // Which tile the keyboard is on.
    property int current: 0

    // Which tile is armed, or -1.
    property int armed: -1

    // Lock is done the moment it is pressed; the other two take the session with them.
    readonly property var tiles: [
      {
        glyph: Icons.lock,
        label: "Lock",
        confirms: false
      },
      {
        glyph: Icons.reboot,
        label: "Restart",
        confirms: true
      },
      {
        glyph: Icons.shutdown,
        label: "Power Off",
        confirms: true
      }
    ]

    readonly property int count: tiles.length

    readonly property int contentWidth: Theme.powerInset * 2 + count * Theme.powerTileWidth + (count - 1) * Theme.powerTileGap

    function tileX(i) {
      return Theme.powerInset + i * (Theme.powerTileWidth + Theme.powerTileGap);
    }

    onOpening: {
      current = 0;
      armed = -1;
    }

    // Moving disarms, so an armed tile is never left waiting for a later Return.
    function move(delta) {
      armed = -1;
      current = (current + delta + count) % count;
    }

    function activate(i) {
      current = i;

      if (tiles[i].confirms && armed !== i) {
        armed = i;
        return;
      }

      win.hide();

      switch (i) {
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

    Process {
      id: systemctl
    }

    onKeyPressed: function (event) {
          switch (event.key) {
          case Qt.Key_Escape:
            // The first Escape stands an armed tile down; the second closes.
            if (win.armed >= 0)
              win.armed = -1;
            else
              win.hide();
            break;
          case Qt.Key_Left:
          case Qt.Key_H:
          case Qt.Key_Backtab:
            win.move(-1);
            break;
          case Qt.Key_Right:
          case Qt.Key_L:
          case Qt.Key_Tab:
            win.move(1);
            break;
          case Qt.Key_Return:
          case Qt.Key_Enter:
          case Qt.Key_Space:
            win.activate(win.current);
            break;
          default:
            return;
          }
      event.accepted = true;
    }

    Item {
      id: body

      anchors.fill: parent
      opacity: win.open || win.origin.held ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        enabled: !win.origin.held

        Morph {
          duration: Theme.morphContent
        }
      }

        ChoiceTiles {
          model: win.tiles
          currentIndex: win.current
          activeIndex: win.armed
          activeColor: Theme.love
          activeLabel: "Confirm"
          activeIsCommitting: true
          onEntered: function (index) {
            if (win.armed < 0)
              win.current = index;
          }
          onActivated: win.activate(index)
        }
      }
    }
  }
