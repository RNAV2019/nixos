import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power profiles card. Board 04b, and the island in another shape.
//
// Built on the same plan as the power menu: not a panel, but the island
// itself in another shape. It starts at the pill's own size, radius and
// centre line and grows in its place on the power menu's own morph, and
// shrinks back into the pill when it is done. The tile grid is the power
// menu's and the recorder picker's, to the pixel - three surfaces that ask
// "which of these three" do not ask it in three different shapes.
//
// Where the power menu arms before it commits, this card commits at once:
// a profile switch is instant and reversible, so there is nothing to confirm
// and nothing to stand down. Choosing is the power menu's commit without the
// arm: the tile takes the profile, the card melts back into the pill on the
// same curve it grew out of it, and the bar's island comes back.
//
// The active tile is love, per the board: it is the one thing on screen that
// says the machine's whole stance has changed, and it must not read as one
// more thing that is merely on.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "profiles"
    openWidth: win.contentWidth
    openHeight: Theme.powerHeight
    openRadius: Theme.recorderRadius

    // Which tile the keyboard is on.
    property int current: 0

    // Raised while the island is being handed to another surface. While the
    // handover's still is held, this surface's shape rides the taker's own
    // morph; handover is also what keeps the final cut to the pill - once
    // the still is taken down, covered by the taker - instant. See
    // Ui/IslandOrigin.qml.
    // The shape this surface grows out of, and the handover protocol it
    // follows when another surface takes the island: adopt the island's
    // card, claim, take the shape the holder was wearing. One of these for
    // each of the surfaces that stand in for the island.
    readonly property var tiles: [
      {
        key: "performance",
        label: "Performance",
        glyph: Icons.bolt
      },
      {
        key: "balanced",
        label: "Balanced",
        glyph: Icons.contrast
      },
      {
        key: "power-saver",
        label: "Power Saver",
        glyph: Icons.batterySaver
      }
    ]

    readonly property int count: tiles.length

    readonly property int contentWidth: Theme.recorderInset * 2 + count * Theme.recorderTileWidth + (count - 1) * Theme.recorderTileGap

    function tileX(i) {
      return Theme.recorderInset + i * (Theme.recorderTileWidth + Theme.recorderTileGap);
    }

    onOpening: {
      current = Math.max(0, ["performance", "balanced", "power-saver"].indexOf(PowerProfiles.profile));
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it.
    }

    // Giving the island up to the surface that claimed it. The still this
    // leaves behind is what the eye sees until the taker's first frame
    // lands; see Ui/IslandOrigin.qml.
    // Moving never commits, so unlike the power menu there is nothing to
    // disarm.
    function move(delta) {
      current = (current + delta + count) % count;
    }

    // Commit closes the card first and switches second, on the power menu's
    // ordering: the shape leaves before the work happens, so the eye never
    // sees the card linger over a change already made.
    function activate(i) {
      current = i;
      if (!PowerProfiles.available)
        return;
      win.hide();
      PowerProfiles.set(win.tiles[i].key);
    }

    onKeyPressed: function (event) {
          switch (event.key) {
          case Qt.Key_Escape:
          case Qt.Key_Backspace:
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

        // The daemon's answer is the truth; with nothing answering, the tiles
        // grey out rather than offering a picker that does nothing. A nested
        // item, because the body's own opacity is the open/close fade.
        Item {
          anchors.fill: parent
          opacity: PowerProfiles.available ? 1 : 0.5

          Behavior on opacity {
            Morph {
              duration: Theme.morphState
            }
          }

          ChoiceTiles {
            inset: Theme.recorderInset
            model: win.tiles
            currentIndex: win.current
            activeIndex: PowerProfiles.available ? ["performance", "balanced", "power-saver"].indexOf(PowerProfiles.profile) : -1
            activeColor: Theme.love
            onEntered: win.current = index
            onActivated: win.activate(index)
          }
        }
      }
  }
}
