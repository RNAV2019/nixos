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

    // Tall enough for the island's expanded card; the strip itself is transparent.
    implicitHeight: Theme.islandExpandedHeight
    margins.top: Theme.barMarginTop

    // Windows give way to the resting strip only; an expanded card floats over them.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight

    // Input is taken only where a surface actually is; the rest stays click-through.
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

    // The launcher and the control centre cover the island, which stays mapped for
    // handoff timing but is not painted, so it cannot enter the panel's blur sample.
    Island {
      id: island

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      screenOffsetY: Theme.barMarginTop
      screenName: bar.screen ? bar.screen.name : ""
      suppressed: bar.screen !== null && (Bus.islandTaken(bar.screen.name) || Bus.osdScreen === bar.screen.name || Bus.notifyScreen === bar.screen.name)
      replaced: bar.screen !== null && Bus.islandReplaced(bar.screen.name)
      onClockActivated: Bus.toggleSurface("calendar")
      onStatusActivated: Bus.toggleSurface("control")
    }
  }
}
