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
    Button {
      kind: Button.Icon
      icon: Icons.refresh
      enabled: root.active
      accessibleName: "Rescan"

      onClicked: if (NetworkInfo.wifiDevice)
        NetworkInfo.wifiDevice.scannerEnabled = true
    },
    Switch {
      checked: Networking.wifiEnabled
      enabled: Networking.wifiHardwareEnabled

      Accessible.role: Accessible.CheckBox
      Accessible.name: "Wi-Fi"
      Accessible.checkable: true
      Accessible.checked: checked
      Accessible.focusable: true

      onToggled: function (v) {
        Networking.wifiEnabled = v;
      }
    }
  ]

  SectionLabel {
    width: parent.width
    visible: root.wired !== null
    title: "Wired"
  }

  ListRow {
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

  ListRow {
    id: activeRow

    width: parent.width
    visible: root.activeNetwork !== null
    glyphGrid: 24
    glyph: Icons.wifiGlyph(root.activeNetwork ? root.activeNetwork.signalStrength : 0, true)
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
    trailing: [
      Button {
        size: Button.Compact
        text: "Disconnect"
        kind: Button.OnAccent
        onClicked: NetworkInfo.disconnect(root.activeNetwork)
      },
      Button {
        size: Button.Compact
        text: "Forget"
        kind: Button.OnAccent
        onClicked: NetworkInfo.forget(root.activeNetwork)
      }
    ]
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

      ListRow {
        id: row

        width: parent.width
        // Any network in range lights the dot and inner bar, as the island does for a link.
        glyphGrid: 24
        glyph: Icons.wifiGlyph(entry.strength, true)
        label: entry.name
        onClicked: {
          if (entry.needsPassword)
            root.pendingSsid = root.pendingSsid === entry.name ? "" : entry.name;
          else
            networks.objectFor(entry.key).connectWithSettings();
        }

        trailing: [
          Button {
            size: Button.Compact
            kind: Button.Plain
            text: entry.busy ? "…" : "Connect"
            onClicked: {
              if (entry.needsPassword)
                root.pendingSsid = entry.name;
              else
                networks.objectFor(entry.key).connectWithSettings();
            }
          },
          StrokeIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.secured
            size: Theme.sectionSize
            path: Icons.lock
            color: Theme.muted
          }
        ]
      }

      Item {
        id: passwordRow

        readonly property bool open: root.pendingSsid === entry.name
        // The row's own height; the field and the button keep their 40 px inside the clip,
        // so the row uncovers them rather than squeezing them.
        readonly property real fullHeight: 40

        width: parent.width
        height: heightSpring.value
        opacity: passwordRow.height / passwordRow.fullHeight
        // Stays drawn through the collapse so the fade-out is seen, not just the pop-in.
        visible: open || height > 0
        clip: true

        MorphSpring {
          id: heightSpring

          target: passwordRow.open ? passwordRow.fullHeight : 0
          label: "wifi.pass." + entry.key.replace(/\s+/g, "_")
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

        Item {
          width: parent.width
          height: passwordRow.fullHeight

          TextField {
            id: psk

            x: Theme.controlRowInset
            width: parent.width - x - join.width - 10
            anchors.verticalCenter: parent.verticalCenter
            placeholder: "Password"
            echoPassword: true
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

          Button {
            id: join

            size: Button.Compact
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            kind: Button.Plain
            text: "Join"
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
}
