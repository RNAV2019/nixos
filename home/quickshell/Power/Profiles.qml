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
    openWidth: Theme.panelWidth(modelData, grid.contentWidth)
    openHeight: Theme.powerHeight
    openRadius: Theme.powerRadius

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

    ConfirmGrid {
      id: grid

      surface: win
      model: win.tiles
      available: PowerProfiles.available
      initialIndex: Math.max(0, win.profileOrder.indexOf(PowerProfiles.profile))
      marked: PowerProfiles.available ? win.profileOrder.indexOf(PowerProfiles.profile) : -1

      onCommitted: function (index) {
        PowerProfiles.set(win.profileOrder[index]);
      }
    }
  }
}
