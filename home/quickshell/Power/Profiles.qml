import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power profiles card: unlike the power menu it commits at once, since a profile
// switch is instant and reversible.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "profiles"
    openWidth: Theme.panelWidth(modelData, win.contentWidth)
    openHeight: Theme.powerHeight
    openRadius: Theme.recorderRadius

    property int current: 0

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
    }

    function move(delta) {
      current = (current + delta + count) % count;
    }

    // Close first, switch second, so the eye never sees the card linger over a done change.
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

        // With nothing answering, the tiles grey out. Nested, because the body's own
        // opacity is the open/close fade.
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
