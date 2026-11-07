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

    // From the screen's top edge down past the island's expanded card and its drop shadow;
    // the strip is transparent. Starting at the edge rather than at the pill keeps the shadow
    // above the pill from being cut off by the window, and the room below lets it fall.
    implicitHeight: Theme.barMarginTop + Theme.islandExpandedHeight + Theme.oledShiftMax + Theme.surfaceShadowRoom

    // Windows give way to the resting strip only; an expanded card floats over them.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barMarginTop + Theme.barHeight

    // Input is taken only where a surface actually is; the rest stays click-through.
    mask: Region {
      Region {
        item: workspaces
      }

      Region {
        item: island.suppressed ? null : island
      }

      Region {
        x: satellite.hitX
        y: satellite.hitY
        width: satellite.hitActive ? satellite.hitSize : 0
        height: satellite.hitActive ? satellite.hitSize : 0
      }
    }

    Workspaces {
      id: workspaces

      // Sits at Hyprland's gaps_out, so the pill's left edge lines up with the leftmost window.
      x: snap(10 + Bus.workspacesOffsetX)
      y: snap(Theme.barMarginTop + Bus.workspacesOffsetY)
      screenOffsetY: Theme.barMarginTop
    }

    // The launcher and control centre cover the island; it stays mapped for handoff
    // timing but is not painted, so it cannot enter the panel's blur sample.
    Island {
      id: island

      // Centred by hand rather than anchored, so the card lands on the device-pixel grid.
      x: snap((parent.width - width) / 2 + Bus.pillOffsetX)
      y: snap(Theme.barMarginTop + Bus.pillOffsetY)
      screenOffsetY: Theme.barMarginTop
      screenName: bar.screen ? bar.screen.name : ""
      // Off covers, not owners: a surface covers the pill from its first frame on screen, so
      // the pill is never taken away before something is drawn in its place.
      suppressed: bar.screen !== null && (Bus.islandCovered(bar.screen.name) || Bus.transientOnScreen(bar.screen.name))
      replaced: bar.screen !== null && Bus.islandReplaced(bar.screen.name)
    }

    // KDE Connect's phone, budding out of the island's right end; drawn after it, so the
    // bridge between them lies over the pill's outline.
    PhoneSatellite {
      id: satellite

      anchors.fill: parent
      pill: island
      screenName: bar.screen ? bar.screen.name : ""
      windowTop: 0
    }
  }
}
