import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Control
import qs.Services
import qs.Ui

// Quickshell's Networking API has no disconnect or forget, so those go via nmcli.
ControlSubView {
  id: root

  title: "Wi-Fi"
  accessibleName: "Wi-Fi settings"

  // The network whose password field is open, if any.
  property string pendingSsid: ""

  readonly property var wired: NetworkInfo.wiredDevice
  readonly property var activeNetwork: NetworkInfo.activeNetwork
  readonly property var others: NetworkInfo.otherNetworks

  // Scanning costs radio, so it runs only while this view is on screen.
  onActiveChanged: {
    if (active) {
      scanOn.restart();
    } else {
      scanOn.stop();
      if (NetworkInfo.wifiDevice)
        NetworkInfo.wifiDevice.scannerEnabled = false;
      pendingSsid = "";
    }
  }

  function backKeyPressed() {
    if (root.pendingSsid !== "")
      root.pendingSsid = "";
    else
      root.backed();
  }

  function runNmcli(args) {
    // A second nmcli while one is still running would clobber its command.
    if (nmcli.running)
      return;
    nmcli.command = ["nmcli"].concat(args);
    nmcli.running = true;
  }

  Process {
    id: nmcli
  }

  Timer {
    id: scanOn

    interval: Theme.morphSurface + 100
    onTriggered: if (root.active && NetworkInfo.wifiDevice)
      NetworkInfo.wifiDevice.scannerEnabled = true
  }

  headerTrailing: [
    Switch {
      checked: Networking.wifiEnabled
      interactive: Networking.wifiHardwareEnabled

      Accessible.role: Accessible.CheckBox
      Accessible.name: "Wi-Fi"
      Accessible.checkable: true
      Accessible.checked: checked
      Accessible.focusable: true

      onToggled: function (v) {
        Networking.wifiEnabled = v;
      }
    },
    IconButton {
      text: Icons.refresh
      baseColor: Theme.subtle
      hoverColor: Theme.text
      font.family: Theme.iconFont
      font.pixelSize: 16
      hitSlop: 8
      enabled: root.active
      accessibleName: "Rescan"

      onClicked: if (NetworkInfo.wifiDevice)
        NetworkInfo.wifiDevice.scannerEnabled = true
    }
  ]

  SectionLabel {
    width: parent.width
    visible: root.wired !== null
    title: "Wired"
  }

  DeviceRow {
    width: parent.width
    visible: root.wired !== null
    glyph: Icons.ethernet
    label: root.wired ? root.wired.name : ""
    sublabel: root.wired && root.wired.connected ? "Connected" : "Cable unplugged"
    selected: root.wired !== null && root.wired.connected
  }

  SectionLabel {
    width: parent.width
    visible: root.activeNetwork !== null
    title: "Wi-Fi network"
  }

  DeviceRow {
    width: parent.width
    visible: root.activeNetwork !== null
    glyph: root.activeNetwork ? Icons.step(Icons.wifi, root.activeNetwork.signalStrength * 100) : ""
    label: root.activeNetwork ? root.activeNetwork.name : ""
    sublabel: {
      if (!root.activeNetwork)
        return "";
      var parts = ["Connected"];
      if (NetworkInfo.secured(root.activeNetwork))
        parts.push("Secured");
      return parts.join(" · ");
    }
    selected: true

    PillButton {
      label: "Disconnect"
      onAccent: true
      onClicked: if (root.activeNetwork)
        root.runNmcli(["device", "disconnect", root.activeNetwork.device.name])
    }

    PillButton {
      label: "Forget"
      onAccent: true
      onClicked: if (root.activeNetwork)
        root.runNmcli(["connection", "delete", "id", root.activeNetwork.name])
    }
  }

  SectionLabel {
    width: parent.width
    visible: Networking.wifiEnabled
    title: "Available networks"
    note: root.others.length === 0 ? "Scanning…" : ""
  }

  Text {
    width: parent.width
    visible: !Networking.wifiEnabled
    text: "Wi-Fi is off"
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize
    topPadding: 10
  }

  Repeater {
    model: root.active && Networking.wifiEnabled ? root.others : []

    Column {
      id: entry

      required property var modelData

      readonly property bool needsPassword: NetworkInfo.secured(modelData) && !modelData.known

      width: parent.width
      spacing: Theme.controlRowGap

      DeviceRow {
        width: parent.width
        glyph: Icons.step(Icons.wifi, entry.modelData.signalStrength * 100)
        label: entry.modelData.name
        onClicked: {
          if (entry.needsPassword)
            root.pendingSsid = root.pendingSsid === entry.modelData.name ? "" : entry.modelData.name;
          else
            entry.modelData.connectWithSettings();
        }

        PillButton {
          label: entry.modelData.stateChanging ? "…" : "Connect"
          onClicked: {
            if (entry.needsPassword)
              root.pendingSsid = entry.modelData.name;
            else
              entry.modelData.connectWithSettings();
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: NetworkInfo.secured(entry.modelData)
          text: Icons.lock
          color: Theme.muted
          font.family: Theme.iconFont
          font.pixelSize: Theme.controlSectionSize
        }
      }

      Item {
        id: passwordRow

        readonly property bool open: root.pendingSsid === entry.modelData.name

        width: parent.width
        height: open ? 40 : 0
        opacity: open ? 1 : 0
        // Stays drawn through the collapse so the fade-out is seen, not just the pop-in.
        visible: open || height > 0
        clip: true

        Behavior on height {
          NumberAnimation {
            duration: Theme.duration(Theme.morphState)
            easing.type: Easing.OutCubic
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.duration(Theme.morphState)
            easing.type: Easing.OutCubic
          }
        }

        onOpenChanged: {
          if (open) {
            Qt.callLater(function () {
              if (passwordRow.visible && root.active)
                psk.inputItem.forceActiveFocus();
            });
          } else {
            psk.text = "";
            if (psk.inputItem.activeFocus)
              root.forceActiveFocus();
          }
        }

        PanelTextField {
          id: psk

          x: Theme.controlRowInset
          width: parent.width - x - join.width - 10
          anchors.verticalCenter: parent.verticalCenter
          placeholder: "Password"
          accessibleName: "Wi-Fi password"
          onCancelled: {
            root.pendingSsid = "";
            psk.text = "";
          }
          onAccepted: function (text) {
            entry.modelData.connectWithPsk(text);
            root.pendingSsid = "";
            psk.text = "";
          }
        }

        PillButton {
          id: join

          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
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
