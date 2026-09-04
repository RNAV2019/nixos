import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.Commons
import qs.Ui

// Limit discovery to the active panel to avoid persistent radio scanning.
PanelContent {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter

  readonly property var paired: {
    if (!adapter)
      return [];
    var out = [];
    for (var i = 0; i < adapter.devices.values.length; i++) {
      if (adapter.devices.values[i].paired)
        out.push(adapter.devices.values[i]);
    }
    return out;
  }

  // BlueZ uses the MAC address when a device advertises no name.
  function isMacName(name) {
    return /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/.test(name);
  }

  readonly property var discovered: {
    if (!adapter)
      return [];
    var out = [];
    for (var i = 0; i < adapter.devices.values.length; i++) {
      var d = adapter.devices.values[i];
      if (!d.paired && d.name && !isMacName(d.name))
        out.push(d);
    }
    return out;
  }

  onActiveChanged: {
    if (adapter && adapter.enabled)
      adapter.discovering = active;
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

      SectionHeader {
        title: "Bluetooth"
        Layout.fillWidth: true
      }

      PanelToggle {
        checked: root.adapter !== null && root.adapter.enabled
        enabled: root.adapter !== null
        onToggled: function (v) {
          if (root.adapter) {
            root.adapter.enabled = v;
            if (v)
              root.adapter.discovering = root.active;
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: root.adapter === null
      text: "No bluetooth controller"
      color: Theme.muted
      font.family: Theme.uiFont
      font.pixelSize: Theme.fontSize
    }

    SectionHeader {
      title: "Paired"
      visible: root.paired.length > 0
    }

    Repeater {
      model: root.paired

      PanelRow {
        id: pairedRow

        required property var modelData

        Layout.fillWidth: true
        selected: modelData.connected
        onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()

        Text {
          id: pairedName
          anchors.left: parent.left
          anchors.right: pairedActions.left
          anchors.rightMargin: Theme.spacingMd
          anchors.verticalCenter: parent.verticalCenter
          text: pairedRow.modelData.name
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }

        RowLayout {
          id: pairedActions
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Theme.spacingMd

          Text {
            text: {
              if (pairedRow.modelData.state === BluetoothDeviceState.Connecting)
                return "Connecting…";
              if (pairedRow.modelData.state === BluetoothDeviceState.Disconnecting)
                return "Disconnecting…";
              if (pairedRow.modelData.connected)
                return pairedRow.modelData.batteryAvailable ? Math.round(pairedRow.modelData.battery * 100) + "%" : "Connected";
              return "";
            }
            color: Theme.foam
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSizeSmall
            font.letterSpacing: Theme.trackingLabel
          }

          PanelButton {
            label: "Forget"
            destructive: true
            visible: pairedRow.hovered
            onClicked: pairedRow.modelData.forget()
          }
        }
      }
    }

    SectionHeader {
      title: "Available"
      visible: root.discovered.length > 0
    }

    Repeater {
      model: root.discovered

      PanelRow {
        id: newRow

        required property var modelData

        Layout.fillWidth: true
        onClicked: modelData.pairing ? modelData.cancelPair() : modelData.pair()

        Text {
          anchors.left: parent.left
          anchors.right: newState.left
          anchors.rightMargin: Theme.spacingMd
          anchors.verticalCenter: parent.verticalCenter
          text: newRow.modelData.name
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }

        Text {
          id: newState
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: newRow.modelData.pairing ? "Pairing…" : (newRow.hovered ? "Pair" : "")
          color: Theme.muted
          font.family: Theme.uiFont
          font.pixelSize: Theme.fontSizeSmall
          font.letterSpacing: Theme.trackingLabel
        }
      }
    }
  }
}
