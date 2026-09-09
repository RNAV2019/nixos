import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Bar.Widgets
import qs.Commons
import qs.Panels
import qs.Ui

Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: bar

    required property var modelData

    property string openPanel: ""

    // IPC panel requests target the focused monitor.
    readonly property bool focused: Monitors.isFocused(bar.screen)

    function toggle(name) {
      openPanel = openPanel === name ? "" : name;
    }

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

    Connections {
      target: Bus

      function onTogglePanel(name) {
        if (!bar.focused)
          return;
        if (name === "session")
          Bus.sessionToggled();
        else
          bar.toggle(name);
      }

      function onClosePanels() {
        bar.openPanel = "";
      }
    }

    // PanelHost cards use this item's coordinate space.
    Item {
      id: barBody

      // Nothing in the strip is a click-through target for an open panel any
      // more: a click outside a panel simply dismisses it.
      readonly property var clickTargets: []

      anchors.fill: parent

      Workspaces {
        id: workspaces

        anchors.left: parent.left
        anchors.leftMargin: Theme.barMarginLeft
        anchors.top: parent.top
        screenOffsetY: Theme.barMarginTop
      }

      // The launcher and the control centre both grow out of the island's own
      // pill, in the island's own place, and cover it for as long as they are
      // open. The island is left drawn underneath rather than taken away, so
      // there is never a frame with neither on screen; all it has to do is stay
      // collapsed, so that nothing of it shows around their first frames.
      Island {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        screenOffsetY: Theme.barMarginTop
        suppressed: bar.screen !== null && Bus.islandTaken(bar.screen.name)
        replaced: bar.screen !== null && Bus.islandReplaced(bar.screen.name)
        onClockActivated: bar.toggle("clock")
        // The status chip is the card's quick-settings summary - the radio and
        // the battery, the two readings the control centre is about - so it is
        // the control centre's own button, and pressing it grows the card into
        // the panel rather than opening a separate one below the bar.
        onStatusActivated: Bus.controlToggled()
      }

      // Panels open under the island, which is the surface every one of them
      // morphs out of.
      PanelHost {
        barItem: barBody
        activePanel: bar.openPanel
        onDismissed: bar.openPanel = ""

        ClockPanel {
          panelName: "clock"
          anchorTarget: island
        }

        DisplayPanel {
          panelName: "displays"
          anchorTarget: island
        }

        BluetoothPanel {
          panelName: "bluetooth"
          anchorTarget: island
        }

        NetworkPanel {
          panelName: "network"
          anchorTarget: island
        }

        AudioPanel {
          panelName: "audio"
          anchorTarget: island
        }

        SystemPanel {
          panelName: "system"
          anchorTarget: island
        }

        BatteryPanel {
          panelName: "battery"
          anchorTarget: island
        }
      }
    }
  }
}
