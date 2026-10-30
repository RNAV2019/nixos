import QtQuick
import Quickshell.Networking
import qs.Commons
import qs.Control
import qs.Services
import qs.Ui

ControlSubView {
  id: root

  title: "Wi-Fi"
  accessibleName: "Wi-Fi settings"

  // The network whose password field is open, if any.
  property string pendingSsid: ""

  readonly property var wired: NetworkInfo.wiredDevice
  readonly property var activeNetwork: NetworkInfo.activeNetwork
  readonly property var others: NetworkInfo.otherNetworks

  // The scan as the list shows it, keyed by name and security. Strength alone reorders
  // neighbours on every poll, so rows are ranked by tenths of it and then by name.
  readonly property var snapshot: {
    var entries = [];
    var byKey = {};
    if (active && Networking.wifiEnabled) {
      var ranked = others.slice().sort(function (a, b) {
        var tier = Math.round(b.signalStrength * 10) - Math.round(a.signalStrength * 10);
        if (tier !== 0)
          return tier;
        return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
      });
      for (var i = 0; i < ranked.length; i++) {
        var n = ranked[i];
        var key = n.name + "|" + n.security;
        byKey[key] = n;
        entries.push({
          "key": key,
          "name": n.name,
          "strength": n.signalStrength,
          "secured": NetworkInfo.secured(n),
          "known": n.known,
          "busy": n.stateChanging
        });
      }
    }
    return {
      "entries": entries,
      "byKey": byKey
    };
  }

  onSnapshotChanged: networks.sync(snapshot.entries, snapshot.byKey)
  Component.onCompleted: networks.sync(snapshot.entries, snapshot.byKey)

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
    id: activeRow

    width: parent.width
    visible: root.activeNetwork !== null
    icon: Component {
      WifiMark {
        strength: root.activeNetwork ? root.activeNetwork.signalStrength : 0
        connected: true
        color: activeRow.glyphColor
      }
    }
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
      onClicked: NetworkInfo.disconnect(root.activeNetwork)
    }

    PillButton {
      label: "Forget"
      onAccent: true
      onClicked: NetworkInfo.forget(root.activeNetwork)
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

  KeyedList {
    id: networks

    width: parent.width
    animated: root.active

    delegate: Column {
      id: entry

      required property string key
      required property string name
      required property real strength
      required property bool secured
      required property bool known
      required property bool busy

      readonly property bool needsPassword: secured && !known

      width: networks.width
      spacing: Theme.controlRowGap

      DeviceRow {
        id: row

        width: parent.width
        // Any network in range lights the dot and inner bar, as the island does for a link.
        icon: Component {
          WifiMark {
            strength: entry.strength
            connected: true
            color: row.glyphColor
          }
        }
        label: entry.name
        onClicked: {
          if (entry.needsPassword)
            root.pendingSsid = root.pendingSsid === entry.name ? "" : entry.name;
          else
            networks.objectFor(entry.key).connectWithSettings();
        }

        PillButton {
          label: entry.busy ? "…" : "Connect"
          onClicked: {
            if (entry.needsPassword)
              root.pendingSsid = entry.name;
            else
              networks.objectFor(entry.key).connectWithSettings();
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: entry.secured
          text: Icons.lock
          color: Theme.muted
          font.family: Theme.iconFont
          font.pixelSize: Theme.sectionSize
        }
      }

      Item {
        id: passwordRow

        readonly property bool open: root.pendingSsid === entry.name

        width: parent.width
        height: open ? 40 : 0
        opacity: open ? 1 : 0
        // Stays drawn through the collapse so the fade-out is seen, not just the pop-in.
        visible: open || height > 0
        clip: true

        Behavior on height {
          Morph {
            duration: Theme.duration(Theme.morphState)
          }
        }

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphState)
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
            networks.objectFor(entry.key).connectWithPsk(text);
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
            networks.objectFor(entry.key).connectWithPsk(psk.text);
            root.pendingSsid = "";
            psk.text = "";
          }
        }
      }
    }
  }
}
