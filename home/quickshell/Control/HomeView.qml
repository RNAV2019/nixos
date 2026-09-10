import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import qs.Ui

// The control centre's root view: board 04, laid out at its own metrics.
//
// Nothing here is centred or stretched against the surface it sits in. Every
// position is the design's, measured from the panel's top-left, because the
// surface grows around this rather than this reflowing inside the surface. That
// is what makes the open read as a reveal: the contents are already where they
// will end up on the first frame, and the shape uncovers them.
//
// The header carries no settings button. Board 04 draws one, but no frame of
// the source recording has it, and there is no settings surface for it to open.
Item {
  id: root

  signal closed
  signal opened(string view)

  // The recorder tile asks the panel to hand the island over rather than doing
  // it itself: only the panel knows the box the picker has to contract out of.
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
    for (var i = 0; i < adapter.devices.values.length; i++) {
      if (adapter.devices.values[i].connected)
        return adapter.devices.values[i];
    }
    return null;
  }

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // The layout chain. Each block starts a fixed gap below the one above it, so
  // the panel's height is a sum rather than a constant and a media card that is
  // not drawn does not leave a hole.
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

  // Row one: the narrow tile beside the wide one. The split is the design's -
  // Wi-Fi gets a name, audio gets a device string that needs the room.
  Tile {
    id: wifi

    x: root.inset
    y: root.tilesTop
    width: 156
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
    glyph: root.sink && root.sink.audio && root.sink.audio.muted ? Icons.volumeMuted : Icons.step(Icons.volume, root.sink && root.sink.audio ? root.sink.audio.volume * 100 : 0)
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

  // Row two: three equal tiles. The remainder from the division goes to the
  // last one, so the row still ends on the panel's right inset.
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

  // Board 08. Full width, because its subtitle is the one on this grid with
  // something to say: what is being captured, for how long, and how to stop.
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

  BigSlider {
    x: root.inset
    y: root.slidersTop
    width: root.span
    glyph: root.sink && root.sink.audio && root.sink.audio.muted ? Icons.volumeMuted : Icons.step(Icons.volume, root.sink && root.sink.audio ? root.sink.audio.volume * 100 : 0)
    value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
    dimmed: root.sink !== null && root.sink.audio !== null && root.sink.audio.muted
    onMoved: function (v) {
      if (root.sink && root.sink.audio) {
        root.sink.audio.muted = false;
        root.sink.audio.volume = v;
      }
    }
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

  Text {
    id: clearAll

    x: root.inset + root.span - width
    y: root.sectionTop - 1
    visible: root.count > 0
    text: "Clear all"
    color: clearHover.containsMouse ? Theme.text : Theme.accent
    scale: clearHover.pressed ? 0.97 : 1

    Behavior on color {
      Tint {}
    }

    Behavior on scale {
      Morph { duration: Theme.morphState }
    }
    font.family: Theme.uiFont
    font.pixelSize: 12
    font.weight: Theme.weightMedium

    MouseArea {
      id: clearHover

      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: NotificationStore.clear()
    }
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

        // The card's own property names are the model's, so the delegate reads
        // the row through the model rather than requiring roles it would then
        // be assigning to itself. The rows are snapshots and never change after
        // they are inserted, so a one-shot read is the whole story.
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
