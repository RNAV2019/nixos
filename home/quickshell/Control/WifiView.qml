import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Services
import qs.Ui

// Board 06. The Wi-Fi tile's sub-view: what the machine is on now, and what it
// could be on instead.
//
// Quickshell's Networking API can connect and can join with a passphrase, but
// it exposes neither disconnect nor forget, so those two go out through nmcli.
Item {
  id: root

  property bool active: false

  signal backed

  // The network whose password field is open, if any.
  property string pendingSsid: ""

  readonly property int inset: Theme.controlInset
  readonly property int span: width - inset * 2

  readonly property var wired: NetworkInfo.wiredDevice
  readonly property var activeNetwork: NetworkInfo.activeNetwork
  readonly property var others: NetworkInfo.otherNetworks

  readonly property int contentHeight: Math.min(Theme.controlViewMaxHeight, Theme.controlHeaderHeight + Math.ceil(body.implicitHeight) + Theme.controlPadBottom)

  // Scanning is a radio cost, so it runs only while this view is the one on
  // screen, and it stops a beat after the view leaves rather than the instant
  // it does, which would thrash on a quick trip out and back.
  onActiveChanged: {
    if (active) {
      scanOff.stop();
      scanOn.restart();
    } else {
      scanOn.stop();
      scanOff.restart();
      pendingSsid = "";
    }
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
    onTriggered: if (NetworkInfo.wifiDevice)
      NetworkInfo.wifiDevice.scannerEnabled = true
  }

  Timer {
    id: scanOff

    interval: 8000
    onTriggered: if (NetworkInfo.wifiDevice)
      NetworkInfo.wifiDevice.scannerEnabled = false
  }

  ViewHeader {
    id: header

    width: parent.width
    title: "Wi-Fi"
    onBacked: root.backed()

    Switch {
      checked: Networking.wifiEnabled
      interactive: Networking.wifiHardwareEnabled
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
        model: Networking.wifiEnabled ? root.others : []

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

          // The passphrase field belongs to the row that asked for it, so it
          // opens under that row rather than in a dialogue over the panel.
          Item {
            width: parent.width
            height: visible ? 40 : 0
            visible: root.pendingSsid === entry.modelData.name

            PanelTextField {
              id: psk

              x: Theme.controlRowInset
              width: parent.width - x - join.width - 10
              anchors.verticalCenter: parent.verticalCenter
              placeholder: "Password"
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
