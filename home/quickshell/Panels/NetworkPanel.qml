import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui

PanelContent {
  id: root

  property string pendingSsid: ""

  readonly property var wifiDevice: {
    for (var i = 0; i < Networking.devices.values.length; i++) {
      if (Networking.devices.values[i].type === DeviceType.Wifi)
        return Networking.devices.values[i];
    }
    return null;
  }

  readonly property var wiredDevice: {
    for (var i = 0; i < Networking.devices.values.length; i++) {
      if (Networking.devices.values[i].type === DeviceType.Wired)
        return Networking.devices.values[i];
    }
    return null;
  }

  readonly property var activeNetwork: {
    if (!wifiDevice)
      return null;
    for (var i = 0; i < wifiDevice.networks.values.length; i++) {
      if (wifiDevice.networks.values[i].connected)
        return wifiDevice.networks.values[i];
    }
    return null;
  }

  readonly property var otherNetworks: {
    if (!wifiDevice)
      return [];
    var out = [];
    for (var i = 0; i < wifiDevice.networks.values.length; i++) {
      var n = wifiDevice.networks.values[i];
      if (!n.connected)
        out.push(n);
    }
    out.sort(function (a, b) {
      return b.signalStrength - a.signalStrength;
    });
    return out;
  }

  function secured(network) {
    return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown;
  }

  function runNmcli(args) {
    nmcli.command = ["nmcli"].concat(args);
    nmcli.running = true;
  }

  Process {
    id: nmcli
  }

  // Toggling NetworkManager scanning blocks briefly. Delay enable until the
  // open animation finishes, and linger on disable to avoid UI stalls and
  // scanner churn when the panel is reopened.
  onActiveChanged: {
    if (active) {
      scannerOff.stop();
      scannerOn.restart();
    } else {
      scannerOn.stop();
      scannerOff.restart();
      pendingSsid = "";
    }
  }

  Timer {
    id: scannerOn
    interval: Theme.animSlow + 100
    onTriggered: if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = true
  }

  Timer {
    id: scannerOff
    interval: 8000
    onTriggered: if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = false
  }

  preferredWidth: Theme.panelWidthWide
  scrollable: false

  // Derive list space without depending on ScrollView height, which would
  // create a binding loop. Hold the panel at full height while Wi-Fi is on
  // because delayed scan results arrive after opening.
  readonly property int headerHeight: header.implicitHeight
  readonly property int listHeight: list.implicitHeight
  readonly property int maxBodyHeight: availableHeight - Theme.panelPadding * 2
  bodyHeight: Networking.wifiEnabled ? maxBodyHeight : Math.min(headerHeight + Theme.spacingMd + listHeight, maxBodyHeight)

  ColumnLayout {
    id: header

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    RowLayout {
      Layout.fillWidth: true

      SectionHeader {
        title: "Wi-Fi"
        Layout.fillWidth: true
      }

      PanelToggle {
        checked: Networking.wifiEnabled
        enabled: Networking.wifiHardwareEnabled
        onToggled: function (v) {
          Networking.wifiEnabled = v;
        }
      }
    }

    PanelStat {
      Layout.fillWidth: true
      visible: root.wiredDevice !== null && root.wiredDevice.connected
      label: "Ethernet"
      value: "Connected"
      valueColor: Theme.foam
    }

    PanelRow {
      id: activeRow

      Layout.fillWidth: true
      visible: root.activeNetwork !== null
      selected: true

      Text {
        id: activeIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.activeNetwork ? Icons.step(Icons.wifi, root.activeNetwork.signalStrength * 100) : ""
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
      }

      Text {
        anchors.left: activeIcon.right
        anchors.leftMargin: Theme.spacingLg
        anchors.right: activeState.left
        anchors.rightMargin: Theme.spacingMd
        anchors.verticalCenter: parent.verticalCenter
        text: root.activeNetwork ? root.activeNetwork.name + (root.secured(root.activeNetwork) ? "  󰌾" : "") : ""
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
      }

      Text {
        id: activeState
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Connected"
        color: Theme.foam
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
      }
    }

    // Quickshell's Networking API does not expose disconnect or forget.
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Theme.panelRowInset
      Layout.rightMargin: Theme.panelRowInset
      visible: root.activeNetwork !== null
      spacing: Theme.spacingMd

      PanelButton {
        label: "Disconnect"
        onClicked: root.runNmcli(["device", "disconnect", root.activeNetwork.device.name])
      }

      Item {
        Layout.fillWidth: true
      }

      PanelButton {
        label: "Forget"
        destructive: true
        onClicked: root.runNmcli(["connection", "delete", "id", root.activeNetwork.name])
      }
    }

    SectionHeader {
      title: "Available"
      Layout.topMargin: Theme.spacingSm
      visible: root.otherNetworks.length > 0
    }

    Text {
      Layout.fillWidth: true
      visible: Networking.wifiEnabled && root.otherNetworks.length === 0
      text: "Scanning…"
      color: Theme.muted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
    }
  }

  ScrollView {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: Theme.spacingMd
    anchors.bottom: parent.bottom

    ColumnLayout {
      id: list

      width: parent.width
      spacing: Theme.spacingMd

      Repeater {
        model: root.otherNetworks

        ColumnLayout {
          id: entry

          required property var modelData

          Layout.fillWidth: true
          spacing: Theme.spacingSm

          PanelRow {
            Layout.fillWidth: true
            onClicked: {
              if (root.secured(entry.modelData) && !entry.modelData.known)
                root.pendingSsid = entry.modelData.name;
              else
                entry.modelData.connectWithSettings();
            }

            Text {
              id: signalIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: Icons.step(Icons.wifi, entry.modelData.signalStrength * 100)
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
            }

            Text {
              anchors.left: signalIcon.right
              anchors.leftMargin: Theme.spacingLg
              anchors.right: stateLabel.left
              anchors.rightMargin: Theme.spacingMd
              anchors.verticalCenter: parent.verticalCenter
              text: entry.modelData.name + (root.secured(entry.modelData) ? "  󰌾" : "")
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              elide: Text.ElideRight
            }

            Text {
              id: stateLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: entry.modelData.stateChanging ? "…" : Math.round(entry.modelData.signalStrength * 100) + "%"
              color: Theme.muted
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.panelRowInset + signalIcon.width + Theme.spacingLg
            Layout.rightMargin: Theme.panelRowInset
            visible: root.pendingSsid === entry.modelData.name
            spacing: Theme.spacingMd

            PanelTextField {
              id: psk
              Layout.fillWidth: true
              placeholder: "Password"
              onAccepted: function (text) {
                entry.modelData.connectWithPsk(text);
                root.pendingSsid = "";
                psk.text = "";
              }
            }

            PanelButton {
              label: "Join"
              onClicked: {
                entry.modelData.connectWithPsk(psk.text);
                root.pendingSsid = "";
                psk.text = "";
              }
            }
          }
        }
      }
    }
  }
}
