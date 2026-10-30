import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    // Stays up through a lock, so the snapshot carries the bar and it blurs away with the
    // desktop under the lock screen instead of blinking out first.
    visible: Bus.sessionReady || Bus.locking
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"

    anchors {
      top: true
      left: true
      right: true
    }

    // Tall enough for the island's expanded card; the strip is transparent. The pills sit
    // oledShiftMax inside it, so their burn-in orbit has room either way; the margin and the
    // exclusive zone take that back, leaving the same room for windows.
    implicitHeight: Theme.islandExpandedHeight + 2 * Theme.oledShiftMax
    margins.top: Theme.barMarginTop - Theme.oledShiftMax

    // Windows give way to the resting strip only; an expanded card floats over them.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight + Theme.oledShiftMax

    // Input is taken only where a surface actually is; the rest stays click-through.
    mask: Region {
      Region {
        item: workspaces
      }

      Region {
        item: island.suppressed ? null : island
      }
    }

    Workspaces {
      id: workspaces

      // Sits at Hyprland's gaps_out, so the pill's left edge lines up with the leftmost window.
      x: snap(10 + Bus.workspacesOffsetX)
      y: snap(Theme.oledShiftMax + Bus.workspacesOffsetY)
      opacity: OledCare.level
      screenOffsetY: Theme.barMarginTop
    }

    // The launcher and control centre cover the island; it stays mapped for handoff
    // timing but is not painted, so it cannot enter the panel's blur sample.
    Island {
      id: island

      // Centred by hand rather than anchored, so the card lands on the device-pixel grid.
      x: snap((parent.width - width) / 2 + Bus.pillOffsetX)
      y: snap(Theme.oledShiftMax + Bus.pillOffsetY)
      screenOffsetY: Theme.barMarginTop
      screenName: bar.screen ? bar.screen.name : ""
      // Off covers, not owners: a surface covers the pill from its first frame on screen, so
      // the pill is never taken away before something is drawn in its place.
      suppressed: bar.screen !== null && (Bus.islandCovered(bar.screen.name) || Bus.transientOnScreen(bar.screen.name))
      replaced: bar.screen !== null && Bus.islandReplaced(bar.screen.name)
    }
  }
}
