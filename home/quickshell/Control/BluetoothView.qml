import QtQuick
import Quickshell.Bluetooth
import qs.Commons
import qs.Control
import qs.Ui

// Discovery runs only while this view is on screen; it costs battery on both ends.
ControlSubView {
  id: root

  title: "Bluetooth"
  accessibleName: "Bluetooth settings"

  readonly property var adapter: Bluetooth.defaultAdapter

  // BlueZ falls back to the MAC address when a device advertises no name.
  function isMacName(name) {
    return /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/.test(name);
  }

  // One flat list, so a device that pairs or connects glides to its new section instead of
  // being rebuilt in another list: the section headings are rows too. Keyed by address.
  readonly property var snapshot: {
    var entries = [];
    var byKey = {};
    if (active && adapter) {
      var connected = [];
      var paired = [];
      var discovered = [];
      var known = adapter.devices.values;
      for (var i = 0; i < known.length; i++) {
        var d = known[i];
        if (d.connected)
          connected.push(d);
        else if (d.paired)
          paired.push(d);
        else if (d.name && !isMacName(d.name))
          discovered.push(d);
      }
      var add = function (section, title, note, group) {
        if (title !== "")
          entries.push(entryFor("~" + section, "header", section, title, note, null));
        for (var j = 0; j < group.length; j++) {
          byKey[group[j].address] = group[j];
          entries.push(entryFor(group[j].address, "device", section, "", "", group[j]));
        }
      };
      if (connected.length > 0)
        add("connected", "Connected", "", connected);
      if (paired.length > 0)
        add("paired", "Paired", "", paired);
      add("available", adapter.enabled ? "Available" : "", discovered.length === 0 ? "Scanning…" : "", discovered);
    }
    return {
      "entries": entries,
      "byKey": byKey
    };
  }

  function entryFor(key, kind, section, title, note, device) {
    return {
      "key": key,
      "kind": kind,
      "section": section,
      "title": title,
      "note": note,
      "name": device ? device.name : "",
      "glyph": device ? glyphFor(device) : "",
      "sub": device ? stateOf(device) : "",
      "pairing": device ? device.pairing : false
    };
  }

  onSnapshotChanged: devices.sync(snapshot.entries, snapshot.byKey)
  Component.onCompleted: devices.sync(snapshot.entries, snapshot.byKey)

  onActiveChanged: {
    if (adapter)
      adapter.discovering = active && adapter.enabled;
  }

  onAdapterChanged: if (adapter)
    adapter.discovering = active && adapter.enabled

  function glyphFor(device) {
    var icon = (device.icon || "").toLowerCase();
    if (icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1 || icon.indexOf("audio") !== -1)
      return Icons.headphone;
    if (icon.indexOf("phone") !== -1)
      return Icons.phone;
    if (icon.indexOf("keyboard") !== -1)
      return Icons.keyboard;
    if (icon.indexOf("mouse") !== -1)
      return Icons.mouse;
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

  headerTrailing: [
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

      onClicked: if (root.adapter && root.adapter.enabled)
        root.adapter.discovering = true
    }
  ]

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

  KeyedList {
    id: devices

    width: parent.width
    animated: root.active

    delegate: Item {
      id: slot

      required property string key
      required property string kind
      required property string section
      required property string title
      required property string note
      required property string name
      required property string glyph
      required property string sub
      required property bool pairing

      readonly property bool isHeader: kind === "header"
      readonly property bool isConnected: section === "connected"
      readonly property bool isPaired: section === "paired"

      width: devices.width
      height: isHeader ? Theme.controlSectionHeight : Theme.controlRowHeight

      function activate() {
        var device = devices.objectFor(key);
        if (!device)
          return;
        if (isConnected)
          device.disconnect();
        else if (isPaired)
          device.connect();
        else if (pairing)
          device.cancelPair();
        else
          device.pair();
      }

      SectionLabel {
        anchors.fill: parent
        visible: slot.isHeader
        title: slot.title
        note: slot.note
      }

      DeviceRow {
        id: deviceRow

        anchors.fill: parent
        visible: !slot.isHeader
        glyph: slot.glyph
        label: slot.name
        sublabel: slot.sub
        selected: slot.isConnected
        onClicked: slot.activate()

        PillButton {
          label: slot.isConnected ? "Disconnect" : slot.isPaired ? "Connect" : slot.pairing ? "Cancel" : "Pair"
          onAccent: slot.isConnected
          onClicked: slot.activate()
        }

        PillButton {
          id: forget

          visible: slot.isConnected || slot.isPaired
          label: "Forget"
          onAccent: slot.isConnected
          destructive: slot.isPaired
          // A paired row's is revealed by the row, then held by itself; see PillButton.revealed.
          revealed: slot.isConnected || deviceRow.hovered || forget.hovered
          onClicked: {
            var device = devices.objectFor(slot.key);
            if (device)
              device.forget();
          }
        }
      }
    }
  }
}
