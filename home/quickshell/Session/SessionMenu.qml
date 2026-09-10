import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power menu. Board 11, and the island in another of its shapes.
//
// It was a dimmed screen with a column of words down the middle. The board
// makes it what every other surface here is: the pill grows in place into a
// short wide card carrying one row of tiles, on the 339 ms the board's own
// motion table gives for an island-to-surface morph, and shrinks back into the
// pill when it is done. Nothing dims; the menu is a surface, not a mode.
//
// Lock acts on the first press. The two that end the session do not: one press
// arms the tile, which turns love and relabels itself Confirm, and only a
// second press on the same tile commits. Moving to another tile disarms the
// first, so an armed tile is never left behind for a later keystroke to fire.
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

    // Which tile is armed, or -1. Only ever one, and only ever one that asks
    // to be.
    property int armed: -1

    // Raised while the island is being handed to another surface. While the
    // handover's still is held, this surface's shape rides the taker's own
    // morph; handover is also what keeps the final cut to the pill - once
    // the still is taken down, covered by the taker - instant. See
    // Ui/IslandOrigin.qml.
    // The shape this surface grows out of, and the handover protocol it
    // follows when another surface takes the island: adopt the island's
    // card, claim, take the shape the holder was wearing. One of these for
    // each of the six surfaces that stand in for the island.
    // Lock is done the moment it is pressed; there is nothing to undo. The
    // other two take the session with them, so they ask first.
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
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it.
    }

    // Giving the island up to the surface that claimed it. The still this
    // leaves behind is what the eye sees until the taker's first frame
    // lands; see Ui/IslandOrigin.qml.
    // Moving disarms. An armed tile that stayed armed while the selection moved
    // away would sit there waiting for a Return meant for something else.
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
