import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Control
import qs.Services
import qs.Ui

Item {
  id: root

  signal closed
  signal opened(string view)

  // Only the panel knows the box the picker contracts out of.
  signal recorderRequested

  property int keyboardIndex: 0

  function keyboardMove(delta) {
    keyboardIndex = (keyboardIndex + delta + 8) % 8;
  }

  function keyboardActivate() {
    switch (keyboardIndex) {
    case 0:
      root.opened("wifi");
      break;
    case 1:
      root.opened("audio");
      break;
    case 2:
      root.opened("bluetooth");
      break;
    case 3:
      NotificationStore.peace = !NotificationStore.peace;
      break;
    case 4:
      if (NightLight.available)
        NightLight.toggle();
      break;
    case 5:
      root.recorderRequested();
      break;
    case 6:
      if (root.sink && root.sink.audio)
        root.sink.audio.muted = !root.sink.audio.muted;
      break;
    case 7:
      Brightness.step(true);
      break;
    }
  }

  readonly property int inset: Theme.controlInset
  readonly property int span: width - inset * 2

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var adapter: Bluetooth.defaultAdapter

  readonly property var connectedDevice: {
    if (!adapter)
      return null;
    var out = Util.filterDevices(adapter.devices.values, function (d) {
      return d.connected;
    });
    return out.length > 0 ? out[0] : null;
  }

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // Peace survives a reboot: every change to the flag is saved, and the saved one is
  // applied once the file is read at startup, unless a toggle has already landed.
  property bool _peaceTouched: false

  Connections {
    target: NotificationStore

    function onPeaceChanged() {
      root._peaceTouched = true;
      peaceState.setText(NotificationStore.peace ? "1" : "0");
    }
  }

  FileView {
    id: peaceState

    path: Paths.stateDir + "/peace"
    printErrors: false

    onLoaded: {
      if (root._peaceTouched)
        return;
      if (peaceState.text().trim() === "1")
        NotificationStore.peace = true;
    }
  }

  // Each block sits a fixed gap below the previous, so a missing card leaves no hole.
  readonly property int tilesTop: Theme.controlHeaderHeight
  readonly property int tilesBottom: tilesTop + Theme.controlTileHeight * 3 + Theme.controlTileGap * 2
  readonly property int slidersTop: tilesBottom + Theme.controlBlockGap
  readonly property int slidersBottom: slidersTop + Theme.controlSliderHeight * 2 + Theme.controlSliderGap
  readonly property int mediaTop: slidersBottom + Theme.controlBlockGap
  readonly property int sectionTop: mediaTop + Theme.controlMediaHeight + Theme.controlSectionGap
  readonly property int listTop: sectionTop + Theme.controlSectionHeight

  readonly property int count: NotificationStore.history.count

  readonly property int listHeight: count > 0 ? Math.min(Theme.controlNotifMaxHeight, Math.ceil(list.implicitHeight)) : 44

  readonly property int contentHeight: listTop + listHeight + Theme.controlPadBottom

  ViewHeader {
    width: parent.width
    title: "Control Center"
    onBacked: root.closed()
  }

  Tile {
    id: wifi

    x: root.inset
    y: root.tilesTop
    // The same third the second row divides the span into; the remainder lands on Audio.
    width: root.thirdWidth
    label: "Wi-Fi"
    glyph: {
      if (NetworkInfo.onEthernet)
        return Icons.ethernet;
      if (!Networking.wifiEnabled)
        return Icons.networkOff;
      return NetworkInfo.activeNetwork ? Icons.step(Icons.wifi, NetworkInfo.activeNetwork.signalStrength * 100) : Icons.wifi[0];
    }
    sublabel: {
      if (NetworkInfo.onEthernet)
        return "Ethernet";
      if (!Networking.wifiEnabled)
        return "Off";
      return NetworkInfo.activeNetwork ? NetworkInfo.activeNetwork.name : "Not connected";
    }
    on: NetworkInfo.onEthernet || (Networking.wifiEnabled && NetworkInfo.activeNetwork !== null)
    keyFocused: root.keyboardIndex === 0
    opensView: true
    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    onOpened: root.opened("wifi")
  }

  Tile {
    id: audio

    x: wifi.x + wifi.width + Theme.controlTileGap
    y: root.tilesTop
    width: root.span - wifi.width - Theme.controlTileGap
    label: "Audio"
    glyph: Volume.glyph(root.sink)
    sublabel: root.sink ? (root.sink.nickname || root.sink.description || root.sink.name) : "No output"
    on: root.sink !== null && root.sink.audio !== null && !root.sink.audio.muted
    keyFocused: root.keyboardIndex === 1
    opensView: true
    onToggled: {
      if (root.sink && root.sink.audio)
        root.sink.audio.muted = !root.sink.audio.muted;
    }
    onOpened: root.opened("audio")
  }

  // Floor division leaves the remainder to the last tile, so the row ends on the inset.
  readonly property int thirdWidth: Math.floor((span - Theme.controlTileGap * 2) / 3)

  Tile {
    id: bluetooth

    x: root.inset
    y: root.tilesTop + Theme.controlTileHeight + Theme.controlTileGap
    width: root.thirdWidth
    label: "Bluetooth"
    glyph: {
      if (!root.adapter)
        return Icons.bluetoothNoAdapter;
      if (!root.adapter.enabled)
        return Icons.bluetoothOff;
      return root.connectedDevice ? Icons.bluetoothConnected : Icons.bluetoothOn;
    }
    sublabel: {
      if (!root.adapter)
        return "No adapter";
      if (!root.adapter.enabled)
        return "Off";
      return root.connectedDevice ? root.connectedDevice.name : "On";
    }
    on: root.adapter !== null && root.adapter.enabled
    keyFocused: root.keyboardIndex === 2
    opensView: true
    onToggled: if (root.adapter)
      root.adapter.enabled = !root.adapter.enabled
    onOpened: root.opened("bluetooth")
  }

  Tile {
    id: peace

    x: bluetooth.x + bluetooth.width + Theme.controlTileGap
    y: bluetooth.y
    width: root.thirdWidth
    label: "Peace"
    glyph: NotificationStore.peace ? Icons.peaceOn : Icons.peaceOff
    sublabel: NotificationStore.peace ? "On" : "Off"
    on: NotificationStore.peace
    keyFocused: root.keyboardIndex === 3
    onToggled: NotificationStore.peace = !NotificationStore.peace
  }

  Tile {
    id: nightLight

    x: peace.x + peace.width + Theme.controlTileGap
    y: bluetooth.y
    width: root.inset + root.span - x
    label: "Night Light"
    glyph: Icons.nightLight
    sublabel: {
      if (!NightLight.available)
        return "Unavailable";
      return NightLight.enabled ? NightLight.temperature + "K" : "Off";
    }
    on: NightLight.enabled
    keyFocused: root.keyboardIndex === 4
    opacity: NightLight.available ? 1 : 0.5
    onToggled: if (NightLight.available)
      NightLight.toggle()
  }

  Tile {
    id: recorder

    x: root.inset
    y: bluetooth.y + Theme.controlTileHeight + Theme.controlTileGap
    width: root.span
    label: Recorder.recording ? "Recording" : "Record"
    glyph: Recorder.recording ? Icons.stop : Icons.record
    sublabel: Recorder.status
    on: Recorder.busy
    keyFocused: root.keyboardIndex === 5
    onToggled: {
      if (Recorder.busy)
        Recorder.stop();
      else
        root.recorderRequested();
    }
  }

  VolumeRow {
    x: root.inset
    y: root.slidersTop
    width: root.span
    showMute: false
    node: root.sink
  }

  BigSlider {
    x: root.inset
    y: root.slidersTop + Theme.controlSliderHeight + Theme.controlSliderGap
    width: root.span
    visible: Brightness.available
    glyph: Icons.brightness
    value: Brightness.value
    onMoved: function (v) {
      Brightness.set(v);
    }

    // When brightness is unavailable this row leaves a gap; reflowing the fixed offset
    // math below it is not worth the churn.
  }

  MediaCard {
    x: root.inset
    y: root.mediaTop
    width: root.span
  }

  Text {
    x: root.inset
    y: root.sectionTop
    text: "Notifications"
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlSectionSize
    font.weight: Theme.weightMedium
  }

  IconButton {
    id: clearAll

    x: root.inset + root.span - width
    y: root.sectionTop - 1
    visible: root.count > 0
    text: "Clear all"
    baseColor: Theme.accent
    hoverColor: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: 12
    font.weight: Theme.weightMedium
    hitSlop: 6
    accessibleName: "Clear all"

    onClicked: NotificationStore.clear()
  }

  Text {
    x: root.inset + 6
    y: root.listTop + 12
    visible: root.count === 0
    text: "Nothing new"
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize
  }

  ScrollView {
    id: notifications

    x: root.inset
    y: root.listTop
    width: root.span
    height: root.listHeight
    visible: root.count > 0

    Column {
      id: list

      width: notifications.width
      spacing: Theme.controlNotifGap

      Repeater {
        model: NotificationStore.history

        // Rows are snapshots that never change, so a one-shot read is enough.
        NotificationCard {
          id: card

          required property int index

          readonly property var row: NotificationStore.history.get(index)

          width: list.width
          appName: row ? row.appName : ""
          summary: row ? row.summary : ""
          body: row ? row.body : ""
          image: row ? row.image : ""
          appIcon: row ? row.appIcon : ""
          urgent: row ? row.urgent : false
          onDismissed: NotificationStore.dismiss(card.index)
        }
      }
    }
  }
}
