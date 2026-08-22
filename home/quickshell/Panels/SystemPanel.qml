import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// Use fast stats polling and run `ps` only while this panel is active.
PanelContent {
  id: root

  onActiveChanged: {
    if (active) {
      SystemStats.subscribe();
      Processes.subscribe();
    } else {
      SystemStats.unsubscribe();
      Processes.unsubscribe();
    }
  }

  function loadColor(v) {
    if (v > 0.85)
      return Theme.love;
    if (v > 0.6)
      return Theme.gold;
    return Theme.foam;
  }

  preferredWidth: Theme.panelWidthWide

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingLg

      ColumnLayout {
        spacing: 0

        Text {
          text: Math.round(SystemStats.cpuUsage * 100) + "%"
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeDisplay
        }

        Text {
          text: "CPU"
          color: Theme.subtle
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }
      }

      Item {
        Layout.fillWidth: true
      }

      ColumnLayout {
        spacing: 0

        Text {
          Layout.alignment: Qt.AlignRight
          text: SystemStats.cpuTemp > 0 ? Math.round(SystemStats.cpuTemp) + "°C" : "—"
          color: SystemStats.cpuTemp > 85 ? Theme.love : Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLarge
        }

        Text {
          Layout.alignment: Qt.AlignRight
          text: "Temp"
          color: Theme.subtle
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }
      }

      ColumnLayout {
        spacing: 0

        Text {
          Layout.alignment: Qt.AlignRight
          text: SystemStats.load1.toFixed(2)
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLarge
        }

        Text {
          Layout.alignment: Qt.AlignRight
          text: "Load"
          color: Theme.subtle
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }
      }
    }

    SectionHeader {
      title: "Cores"
      Layout.topMargin: Theme.spacingSm
    }

    GridLayout {
      Layout.fillWidth: true
      columns: 8
      rowSpacing: Theme.spacingSm
      columnSpacing: Theme.spacingSm

      Repeater {
        model: SystemStats.coreUsage.length

        PanelBar {
          required property int index

          Layout.fillWidth: true
          value: SystemStats.coreUsage[index]
          fillColor: root.loadColor(SystemStats.coreUsage[index])
        }
      }
    }

    SectionHeader {
      title: "Memory"
      Layout.topMargin: Theme.spacingMd
    }

    PanelStat {
      Layout.fillWidth: true
      label: "RAM"
      value: SystemStats.formatKb(SystemStats.memoryUsedKb) + " / " + SystemStats.formatKb(SystemStats.memoryTotalKb)
    }

    PanelBar {
      Layout.fillWidth: true
      value: SystemStats.memoryUsage
      fillColor: root.loadColor(SystemStats.memoryUsage)
    }

    PanelStat {
      Layout.fillWidth: true
      visible: SystemStats.swapTotalKb > 0
      label: "Swap"
      value: SystemStats.formatKb(SystemStats.swapUsedKb) + " / " + SystemStats.formatKb(SystemStats.swapTotalKb)
    }

    PanelBar {
      Layout.fillWidth: true
      visible: SystemStats.swapTotalKb > 0
      value: SystemStats.swapUsage
      fillColor: root.loadColor(SystemStats.swapUsage)
    }

    PanelStat {
      Layout.fillWidth: true
      Layout.topMargin: Theme.spacingSm
      label: "Uptime"
      value: SystemStats.formatUptime()
    }

    Separator {
      Layout.fillWidth: true
      Layout.topMargin: Theme.spacingMd
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingXl

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: Theme.spacingXs

        SectionHeader {
          title: "Top by CPU"
        }

        Repeater {
          model: Processes.byCpu

          PanelStat {
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 18
            label: modelData.name
            value: modelData.cpu.toFixed(1) + "%"
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: Theme.spacingXs

        SectionHeader {
          title: "Top by RAM"
        }

        Repeater {
          model: Processes.byMemory

          PanelStat {
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 18
            label: modelData.name
            value: modelData.mem.toFixed(1) + "%"
          }
        }
      }
    }
  }
}
