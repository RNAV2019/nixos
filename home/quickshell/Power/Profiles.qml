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
    openWidth: Theme.panelWidth(modelData, tilesGrid.contentWidth)
    openHeight: Theme.powerHeight
    openRadius: Theme.recorderRadius

    property int current: 0

    // The profiles in the order the card shows them, and what each one sends to
    // PowerProfiles.
    readonly property var profileOrder: ["performance", "balanced", "power-saver"]

    readonly property var tiles: [
      {
        label: "Performance",
        glyph: Icons.bolt
      },
      {
        label: "Balanced",
        glyph: Icons.contrast
      },
      {
        label: "Power Saver",
        glyph: Icons.batterySaver
      }
    ]

    onOpening: {
      current = Math.max(0, win.profileOrder.indexOf(PowerProfiles.profile));
    }

    function move(delta) {
      current = (current + delta + tilesGrid.count) % tilesGrid.count;
    }

    // Close first, switch second, so the eye never sees the card linger over a done change.
    function activate(i) {
      current = i;
      if (!PowerProfiles.available)
        return;
      win.hide();
      PowerProfiles.set(win.profileOrder[i]);
    }

    onKeyPressed: function (event) {
      switch (event.key) {
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

      // With nothing answering, the tiles grey out. Nested, so the grey-out fades under the
      // one content fade the surface owns.
      Item {
        anchors.fill: parent
        opacity: PowerProfiles.available ? 1 : 0.5

        Behavior on opacity {
          Morph {
            duration: Theme.morphState
          }
        }

        ChoiceTiles {
          id: tilesGrid

          inset: Theme.recorderInset
          model: win.tiles
          currentIndex: win.current
          activeIndex: PowerProfiles.available ? win.profileOrder.indexOf(PowerProfiles.profile) : -1
          activeColor: Theme.love
          onEntered: win.current = index
          onActivated: win.activate(index)
        }
      }
    }
  }
}
