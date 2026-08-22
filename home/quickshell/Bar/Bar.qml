import QtQuick
import Quickshell
import Quickshell.Hyprland
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

    // Which panel this bar currently shows, "" for none. Only one at a time.
    property string openPanel: ""

    // Panels raised over IPC land on whichever monitor has focus.
    readonly property bool focused: Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === bar.screen.name

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

    implicitHeight: Theme.barHeight
    margins.top: Theme.barMarginTop

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

    // Everything the bar draws, in one item. The panel host anchors to this
    // and positions its card in this item's coordinate space.
    Item {
      id: barBody

      anchors.fill: parent

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.barMarginLeft + Theme.barItemGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barItemGap

        NixButton {
          anchors.verticalCenter: parent.verticalCenter
          onActivated: {
            bar.openPanel = "";
            Bus.sessionToggled();
          }
        }

        Clock {
          id: clockWidget
          anchors.verticalCenter: parent.verticalCenter
          onActivated: bar.toggle("clock")
        }

        Mpris {
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Workspaces {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMarginRight
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: rightRow.implicitWidth + Theme.barGroupPadding * 2
        implicitHeight: Theme.barHeight
        radius: height / 2
        color: Theme.base

        Row {
          id: rightRow
          anchors.centerIn: parent
          // Zero: each widget already carries barIconPadding on both sides.
          spacing: 0

          BluetoothWidget {
            id: bluetoothWidget
            anchors.verticalCenter: parent.verticalCenter
            onActivated: bar.toggle("bluetooth")
          }

          NetworkWidget {
            id: networkWidget
            anchors.verticalCenter: parent.verticalCenter
            onActivated: bar.toggle("network")
          }

          VolumeWidget {
            id: volumeWidget
            anchors.verticalCenter: parent.verticalCenter
            onActivated: bar.toggle("audio")
          }

          CpuWidget {
            id: cpuWidget
            anchors.verticalCenter: parent.verticalCenter
            onActivated: bar.toggle("system")
          }

          BatteryWidget {
            id: batteryWidget
            anchors.verticalCenter: parent.verticalCenter
            onActivated: bar.toggle("battery")
          }
        }
      }

      // One host per side. Panels within a host morph into each other; the two
      // sides are independent, so opening the clock while the network panel is
      // up does not send a card sliding the width of the screen.
      PanelHost {
        barItem: barBody
        activePanel: bar.openPanel
        onDismissed: bar.openPanel = ""

        ClockPanel {
          panelName: "clock"
          anchorTarget: clockWidget
        }
      }

      PanelHost {
        barItem: barBody
        activePanel: bar.openPanel
        onDismissed: bar.openPanel = ""

        BluetoothPanel {
          panelName: "bluetooth"
          anchorTarget: bluetoothWidget
        }

        NetworkPanel {
          panelName: "network"
          anchorTarget: networkWidget
        }

        AudioPanel {
          panelName: "audio"
          anchorTarget: volumeWidget
        }

        SystemPanel {
          panelName: "system"
          anchorTarget: cpuWidget
        }

        BatteryPanel {
          panelName: "battery"
          anchorTarget: batteryWidget
        }
      }

      // Suppressed while a panel is open: the panel already says everything the
      // tooltip would, and the two would overlap.
      BarTooltip {
        anchorItem: bluetoothWidget
        text: bluetoothWidget.tooltip
        show: bluetoothWidget.hovered && bar.openPanel === ""
      }

      BarTooltip {
        anchorItem: networkWidget
        text: networkWidget.tooltip
        show: networkWidget.hovered && bar.openPanel === ""
      }

      BarTooltip {
        anchorItem: volumeWidget
        text: volumeWidget.tooltip
        show: volumeWidget.hovered && bar.openPanel === ""
      }

      BarTooltip {
        anchorItem: cpuWidget
        text: cpuWidget.tooltip
        show: cpuWidget.hovered && bar.openPanel === ""
      }

      BarTooltip {
        anchorItem: batteryWidget
        text: batteryWidget.tooltip
        show: batteryWidget.hovered && bar.openPanel === "" && batteryWidget.present
      }
    }
  }
}
