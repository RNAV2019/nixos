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

    // The strip covers more than the surfaces do, so clicks may only be taken
    // where a surface actually is.
    mask: Region {
      item: workspaces

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

      Island {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        screenOffsetY: Theme.barMarginTop
        onClockActivated: bar.toggle("clock")
        onStatusActivated: bar.toggle("network")
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
