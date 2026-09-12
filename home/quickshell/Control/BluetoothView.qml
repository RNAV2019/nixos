import QtQuick
import Quickshell.Bluetooth
import qs.Commons
import qs.Ui

// Discovery runs only while this view is on screen; it costs battery on both ends.
Item {
  id: root

  property bool active: false

  enabled: active
  focus: active
  activeFocusOnTab: true

  Accessible.role: Accessible.Pane
  Accessible.name: "Bluetooth settings"
  Accessible.focusable: true
  Accessible.focused: root.activeFocus

  signal backed

  readonly property int inset: Theme.controlInset
  readonly property int span: width - inset * 2

  readonly property var adapter: Bluetooth.defaultAdapter

  readonly property int contentHeight: Math.min(Theme.controlViewMaxHeight, Theme.controlHeaderHeight + Math.ceil(body.implicitHeight) + Theme.controlPadBottom)

  // BlueZ falls back to the MAC address when a device advertises no name.
  function isMacName(name) {
    return /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/.test(name);
  }

  readonly property var connected: {
    if (!active || !adapter)
      return [];
    var out = [];
    for (var i = 0; i < adapter.devices.values.length; i++) {
      if (adapter.devices.values[i].connected)
        out.push(adapter.devices.values[i]);
    }
    return out;
  }

  readonly property var paired: {
    if (!active || !adapter)
      return [];
    var out = [];
    for (var i = 0; i < adapter.devices.values.length; i++) {
      var d = adapter.devices.values[i];
      if (d.paired && !d.connected)
        out.push(d);
    }
    return out;
  }

  readonly property var discovered: {
    if (!active || !adapter)
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
    if (adapter)
      adapter.discovering = active && adapter.enabled;
  }

  onAdapterChanged: if (adapter)
    adapter.discovering = active && adapter.enabled;

  Keys.onPressed: function (event) {
    if (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Backspace)
      return;
    root.backed();
    event.accepted = true;
  }

  function glyphFor(device) {
    var icon = (device.icon || "").toLowerCase();
    if (icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1 || icon.indexOf("audio") !== -1)
      return Icons.headphone;
    if (icon.indexOf("phone") !== -1)
      return "󰄜";
    if (icon.indexOf("keyboard") !== -1)
      return "󰌌";
    if (icon.indexOf("mouse") !== -1)
      return "󰦋";
    return Icons.bluetoothOn;
  }

  function stateOf(device) {
    if (device.state === BluetoothDeviceState.Connecting)
      return "Connecting…";
    if (device.state === BluetoothDeviceState.Disconnecting)
      return "Disconnecting…";
    if (device.connected && device.batteryAvailable)
      return "Connected · battery " + Math.round(device.battery * 100) + "%";
    if (device.connected)
      return "Connected";
    return "";
  }

  ViewHeader {
    width: parent.width
    title: "Bluetooth"
    onBacked: root.backed()

    Switch {
      checked: root.adapter !== null && root.adapter.enabled
      interactive: root.adapter !== null

      Accessible.role: Accessible.CheckBox
      Accessible.name: "Bluetooth"
      Accessible.checkable: true
      Accessible.checked: checked
      Accessible.focusable: true

      onToggled: function (v) {
        if (!root.adapter)
          return;
        root.adapter.enabled = v;
        root.adapter.discovering = v && root.active;
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
        onClicked: if (root.adapter && root.adapter.enabled)
          root.adapter.discovering = true
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

      Text {
        width: parent.width
        visible: root.adapter === null
        text: "No Bluetooth controller"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: Theme.controlTileLabelSize
        topPadding: 10
      }

      Text {
        width: parent.width
        visible: root.adapter !== null && !root.adapter.enabled
        text: "Bluetooth is off"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: Theme.controlTileLabelSize
        topPadding: 10
      }

      SectionLabel {
        width: parent.width
        visible: root.connected.length > 0
        title: "Connected"
      }

      Repeater {
        model: root.connected

        DeviceRow {
          id: connectedRow

          required property var modelData

          width: body.width
          glyph: root.glyphFor(modelData)
          label: modelData.name
          sublabel: root.stateOf(modelData)
          selected: true
          onClicked: modelData.disconnect()

          PillButton {
            label: "Disconnect"
            onAccent: true
            onClicked: connectedRow.modelData.disconnect()
          }

          PillButton {
            label: "Forget"
            onAccent: true
            onClicked: connectedRow.modelData.forget()
          }
        }
      }

      SectionLabel {
        width: parent.width
        visible: root.paired.length > 0
        title: "Paired"
      }

      Repeater {
        model: root.paired

        DeviceRow {
          id: pairedRow

          required property var modelData

          width: body.width
          glyph: root.glyphFor(modelData)
          label: modelData.name
          sublabel: root.stateOf(modelData)
          onClicked: modelData.connect()

          PillButton {
            label: "Connect"
            onClicked: pairedRow.modelData.connect()
          }

          PillButton {
            id: forget

            label: "Forget"
            destructive: true
            // Revealed by the row, then held by itself; see PillButton.revealed.
            revealed: pairedRow.hovered || forget.hovered
            onClicked: pairedRow.modelData.forget()
          }
        }
      }

      SectionLabel {
        width: parent.width
        visible: root.adapter !== null && root.adapter.enabled
        title: "Available"
        note: root.discovered.length === 0 ? "Scanning…" : ""
      }

      Repeater {
        model: root.discovered

        DeviceRow {
          id: newRow

          required property var modelData

          width: body.width
          glyph: root.glyphFor(modelData)
          label: modelData.name
          onClicked: modelData.pairing ? modelData.cancelPair() : modelData.pair()

          PillButton {
            label: newRow.modelData.pairing ? "Cancel" : "Pair"
            onClicked: newRow.modelData.pairing ? newRow.modelData.cancelPair() : newRow.modelData.pair()
          }
        }
      }
    }
  }
}
