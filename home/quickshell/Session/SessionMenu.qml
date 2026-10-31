import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power menu: the island grown into a card of tiles. Lock acts on the first press;
// the two that end the session arm first and commit only on a second press. A commit
// closes at once; its action waits out the pill's settle-back.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "session"
    openWidth: Theme.panelWidth(modelData, grid.contentWidth)
    openHeight: Theme.powerHeight
    openRadius: Theme.powerRadius

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

    ConfirmGrid {
      id: grid

      surface: win
      model: win.tiles

      onCommitted: function (index) {
        switch (index) {
        case 0:
          Bus.lockRequested();
          break;
        case 1:
          Session.reboot();
          break;
        case 2:
          Session.poweroff();
          break;
        }
      }
    }
  }
}
