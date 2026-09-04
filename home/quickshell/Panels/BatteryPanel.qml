import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

// PowerProfiles requires power-profiles-daemon.
PanelContent {
  id: root

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery !== null && battery.isPresent

  function formatDuration(seconds) {
    if (!seconds || seconds <= 0)
      return "—";
    var h = Math.floor(seconds / 3600);
    var m = Math.floor((seconds % 3600) / 60);
    if (h > 0)
      return h + "h " + m + "m";
    return m + "m";
  }

  readonly property string stateLabel: {
    if (!present)
      return "No battery";
    switch (battery.state) {
    case UPowerDeviceState.Charging:
      return "Charging";
    case UPowerDeviceState.Discharging:
      return "Discharging";
    case UPowerDeviceState.FullyCharged:
      return "Fully charged";
    case UPowerDeviceState.Empty:
      return "Empty";
    case UPowerDeviceState.PendingCharge:
      return "Pending charge";
    case UPowerDeviceState.PendingDischarge:
      return "Pending discharge";
    default:
      return "Unknown";
    }
  }

  preferredWidth: Theme.panelWidthNarrow

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingLg

      Text {
        text: root.present ? Icons.step(root.battery.state === UPowerDeviceState.Charging ? Icons.batteryCharging : Icons.batteryDefault, root.battery.percentage * 100) : ""
        color: Theme.accent
        font.family: Theme.iconFont
        font.pixelSize: Theme.fontSizeDisplayLg
      }

      ColumnLayout {
        spacing: 0

        Text {
          text: root.present ? Math.round(root.battery.percentage * 100) + "%" : "—"
          color: Theme.text
          font.family: Theme.displayFont
          font.pixelSize: Theme.fontSizeDisplay
          font.weight: Theme.weightMedium
          font.letterSpacing: Theme.trackingDisplay
        }

        Text {
          text: root.stateLabel
          color: Theme.subtle
          font.family: Theme.uiFont
          font.pixelSize: Theme.fontSizeSmall
          font.letterSpacing: Theme.trackingLabel
        }
      }

      Item {
        Layout.fillWidth: true
      }
    }

    PanelBar {
      Layout.fillWidth: true
      Layout.topMargin: Theme.spacingSm
      value: root.present ? root.battery.percentage : 0
      fillColor: {
        if (!root.present)
          return Theme.overlay;
        var p = root.battery.percentage * 100;
        if (p <= 10)
          return Theme.love;
        if (p <= 20)
          return Theme.gold;
        return Theme.foam;
      }
    }

    Separator {
      Layout.fillWidth: true
      Layout.topMargin: Theme.spacingMd
    }

    PanelStat {
      Layout.fillWidth: true
      label: root.present && root.battery.state === UPowerDeviceState.Charging ? "Time to full" : "Time remaining"
      value: {
        if (!root.present)
          return "—";
        return root.formatDuration(root.battery.state === UPowerDeviceState.Charging ? root.battery.timeToFull : root.battery.timeToEmpty);
      }
    }

    PanelStat {
      Layout.fillWidth: true
      label: "Power draw"
      value: root.present ? root.battery.changeRate.toFixed(1) + " W" : "—"
    }

    PanelStat {
      Layout.fillWidth: true
      visible: root.present && root.battery.healthSupported
      label: "Health"
      value: root.present ? Math.round(root.battery.healthPercentage) + "%" : "—"
    }

    Separator {
      Layout.fillWidth: true
      Layout.topMargin: Theme.spacingMd
    }

    SectionHeader {
      title: "Power profile"
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingMd

      Repeater {
        model: PowerProfiles.hasPerformanceProfile ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]

        PanelRow {
          id: profileRow

          required property var modelData

          Layout.fillWidth: true
          implicitHeight: 28
          selected: PowerProfiles.profile === modelData
          onClicked: PowerProfiles.profile = modelData

          Text {
            anchors.centerIn: parent
            text: {
              switch (profileRow.modelData) {
              case PowerProfile.PowerSaver:
                return "Saver";
              case PowerProfile.Balanced:
                return "Balanced";
              default:
                return "Performance";
              }
            }
            color: profileRow.selected ? Theme.accent : Theme.text
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            font.weight: profileRow.selected ? Theme.weightMedium : Theme.weightRegular
          }
        }
      }
    }
  }
}
