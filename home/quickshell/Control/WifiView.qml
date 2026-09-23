import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Services
import qs.Ui

// Quickshell's Networking API has no disconnect or forget, so those go via nmcli.
Item {
  id: root

  property bool active: false

  enabled: active
  focus: active
  activeFocusOnTab: true

  Accessible.role: Accessible.Pane
  Accessible.name: "Wi-Fi settings"
  Accessible.focusable: true
  Accessible.focused: root.activeFocus

  signal backed

  // The network whose password field is open, if any.
  property string pendingSsid: ""

  readonly property int inset: Theme.controlInset
  readonly property int span: width - inset * 2

  readonly property var wired: NetworkInfo.wiredDevice
  readonly property var activeNetwork: NetworkInfo.activeNetwork
  readonly property var others: NetworkInfo.otherNetworks

  readonly property int contentHeight: Math.min(Theme.controlViewMaxHeight, Theme.controlHeaderHeight + Math.ceil(body.implicitHeight) + Theme.controlPadBottom)

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

  Keys.onPressed: function (event) {
    if (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Backspace)
      return;
    if (root.pendingSsid !== "")
      root.pendingSsid = "";
    else
      root.backed();
    event.accepted = true;
  }

  function runNmcli(args) {
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

  ViewHeader {
    id: header

    width: parent.width
    title: "Wi-Fi"
    onBacked: root.backed()

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
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.refresh
      color: rescan.containsMouse ? Theme.text : Theme.subtle
      scale: rescan.pressed ? 0.95 : 1

      Behavior on color {
        Tint {}
      }

      Behavior on scale {
        Morph { duration: Theme.morphState }
      }
      font.family: Theme.iconFont
      font.pixelSize: 16

      MouseArea {
        id: rescan

        anchors.fill: parent
        anchors.margins: -8
        enabled: root.active
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (NetworkInfo.wifiDevice)
          NetworkInfo.wifiDevice.scannerEnabled = true
      }
    }
  }

  ScrollView {
    x: root.inset
    y: Theme.controlHeaderHeight
    width: root.span
    height: Math.max(0, root.contentHeight - Theme.controlHeaderHeight - Theme.controlPadBottom)

    Column {
      id: body

      width: root.span
      spacing: Theme.controlRowGap

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

          width: body.width
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

            width: parent.width
            height: visible ? 40 : 0
            visible: root.pendingSsid === entry.modelData.name

            onVisibleChanged: {
              if (visible) {
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
  }
}
