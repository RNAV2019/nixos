import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Bar.Widgets
import qs.Commons
import qs.Ui

Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    visible: Bus.sessionReady
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"

    anchors {
      top: true
      left: true
      right: true
    }

    // Tall enough for the island's expanded card, since the island grows
    // downward out of the strip and a layer surface cannot draw past its own
    // height. The strip is transparent, so only the surfaces are visible.
    implicitHeight: Theme.islandExpandedHeight
    margins.top: Theme.barMarginTop

    // Windows must give way to the resting strip, not to the room the island
    // needs when it opens; an expanded card floats over them instead.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight

    // The strip is far taller than the surfaces resting in it, so input is
    // taken only where a surface actually is and the rest stays click-through.
    // The container region holds no geometry of its own; each surface is a
    // child region unioned into it.
    mask: Region {
      Region {
        item: workspaces
      }

      Region {
        item: island
      }
    }

    Workspaces {
      id: workspaces

      anchors.left: parent.left
      anchors.leftMargin: Theme.barMarginLeft
      anchors.top: parent.top
      screenOffsetY: Theme.barMarginTop
    }

    // The launcher and the control centre both grow out of the island's own
    // pill, in the island's own place, and cover it for as long as they are
    // open. The island stays mapped for handoff timing but is not painted, so
    // it cannot enter the translucent panel's blur sample.
    Island {
      id: island

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      screenOffsetY: Theme.barMarginTop
      screenName: bar.screen ? bar.screen.name : ""
      suppressed: bar.screen !== null && (Bus.islandTaken(bar.screen.name) || Bus.osdScreen === bar.screen.name || Bus.notifyScreen === bar.screen.name)
      replaced: bar.screen !== null && Bus.islandReplaced(bar.screen.name)
      onClockActivated: Bus.toggleSurface("calendar")
      // The status chip is the card's quick-settings summary - the radio and
      // the battery, the two readings the control centre is about - so it is
      // the control centre's own button, and pressing it grows the card into
      // the panel rather than opening a separate one below the bar.
      onStatusActivated: Bus.toggleSurface("control")
    }
  }
}
