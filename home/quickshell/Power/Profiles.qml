import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power profiles card. A profile switch is instant and reversible, so unlike the
// power menu there is no arm-then-confirm; the switch still waits out the pill's settle.
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

    // The switch queued behind the pill's settle-back, or -1. One slot, so a second
    // activate cannot queue a second switch.
    property int pending: -1

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
      cancel();
    }

    function move(delta) {
      current = (current + delta + tilesGrid.count) % tilesGrid.count;
    }

    // Close first, switch second, so the eye never sees the card linger over a done change.
    function activate(i) {
      current = i;
      if (!PowerProfiles.available)
        return;

      // An activate for a profile already queued is a no-op, not a second switch.
      if (pending === i)
        return;
      pending = i;

      win.hide();
      settle.restart();
    }

    // The card is back, so the user is choosing again.
    function cancel() {
      pending = -1;
      settle.stop();
    }

    function commit(i) {
      pending = -1;
      PowerProfiles.set(win.profileOrder[i]);
    }

    Timer {
      id: settle

      interval: Theme.actionSettleDelay
      onTriggered: win.commit(win.pending)
    }

    Connections {
      target: Bus

      // Another surface taking the island means the user moved on; nothing fires under it.
      function onIslandClaimed(screen) {
        if (win.pending >= 0 && win.screen && screen === win.screen.name)
          win.cancel();
      }
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
