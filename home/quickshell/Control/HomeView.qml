import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Control
import qs.Services
import qs.Ui
import "../Ui/Motion.js" as Motion

Item {
  id: root

  signal closed
  signal opened(string view)

  // Only the panel knows the box the picker contracts out of.
  signal recorderRequested

  property int keyboardIndex: 0

  function keyboardMove(delta) {
    keyboardIndex = (keyboardIndex + delta + 10) % 10;
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
      root.opened("displays");
      break;
    case 6:
      ChargeMode.cycle();
      break;
    case 7:
      root.recorderRequested();
      break;
    case 8:
      if (root.sink && root.sink.audio)
        root.sink.audio.muted = !root.sink.audio.muted;
      break;
    case 9:
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

  // Each block sits a fixed gap below the previous, so a missing card leaves no hole.
  readonly property int tilesTop: Theme.panelHeaderHeight
  readonly property int tilesBottom: tilesTop + Theme.controlTileHeight * 3 + Theme.controlTileGap * 2
  readonly property int slidersTop: tilesBottom + Theme.controlBlockGap
  readonly property int slidersBottom: slidersTop + Theme.controlSliderHeight * 2 + Theme.controlSliderGap
  readonly property int mediaTop: slidersBottom + Theme.controlBlockGap
  readonly property int sectionTop: mediaTop + Theme.controlMediaHeight + Theme.controlSectionGap
  readonly property int listTop: sectionTop + Theme.controlSectionHeight

  readonly property int count: NotificationStore.history.count
  // Rows on their way out (see the slot below) still count above; these are the ones staying.
  property int going: 0
  readonly property int live: Math.max(0, count - going)

  // Up once the view is built: rows that arrive after that open, the ones it was built with are
  // placed.
  property bool primed: false

  Component.onCompleted: Qt.callLater(function () {
    root.primed = true;
  })

  // Every row leaves the way one does, together.
  function clearNotifications() {
    for (var i = history.count - 1; i >= 0; i--) {
      var slot = history.itemAt(i);
      if (slot)
        slot.dismiss();
    }
  }

  // Never under the empty line's room: a row is taller than that at rest, so this only shows while
  // the first row opens or the last one shuts, and the card does not dip on the way.
  readonly property int listHeight: Math.min(Theme.controlNotifMaxHeight, Math.max(44, Math.ceil(list.implicitHeight)))

  readonly property int contentHeight: listTop + listHeight + Theme.controlPadBottom

  PanelHeader {
    width: parent.width
    title: "Control Center"
    hasBack: true
    onBacked: root.closed()
  }

  Tile {
    id: wifi

    x: root.inset
    y: root.tilesTop
    // The same third the second row divides the span into; the remainder lands on Audio.
    width: root.thirdWidth
    label: "Wi-Fi"
    glyphGrid: NetworkInfo.onEthernet ? Theme.controlTileGlyphSize : 24
    glyph: NetworkInfo.onEthernet ? Icons.ethernet : Icons.wifiGlyph(NetworkInfo.activeNetwork ? NetworkInfo.activeNetwork.signalStrength : 0, Networking.wifiEnabled && NetworkInfo.activeNetwork !== null)
    glyphDimmed: !NetworkInfo.onEthernet && !(Networking.wifiEnabled && NetworkInfo.activeNetwork !== null)
    sublabel: {
      if (NetworkInfo.onEthernet)
        return "Ethernet";
      if (!Networking.wifiEnabled)
        return "Off";
      return NetworkInfo.activeNetwork ? NetworkInfo.activeNetwork.name : "Not connected";
    }
    active: NetworkInfo.onEthernet || (Networking.wifiEnabled && NetworkInfo.activeNetwork !== null)
    current: root.keyboardIndex === 0
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
    glyph: Volume.glyphFor(root.sink)
    sublabel: root.sink ? (root.sink.nickname || root.sink.description || root.sink.name) : "No output"
    active: root.sink !== null && root.sink.audio !== null && !root.sink.audio.muted
    current: root.keyboardIndex === 1
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
    glyphGrid: 24
    glyph: Icons.bluetoothGlyph(!root.adapter || !root.adapter.enabled, root.connectedDevice !== null)
    sublabel: {
      if (!root.adapter)
        return "No adapter";
      if (!root.adapter.enabled)
        return "Off";
      return root.connectedDevice ? root.connectedDevice.name : "On";
    }
    active: root.adapter !== null && root.adapter.enabled
    current: root.keyboardIndex === 2
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
    active: NotificationStore.peace
    current: root.keyboardIndex === 3
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
    active: NightLight.enabled
    current: root.keyboardIndex === 4
    enabled: NightLight.available
    onToggled: if (NightLight.available)
      NightLight.toggle()
  }

  Tile {
    id: recorder

    x: charge.x + charge.width + Theme.controlTileGap
    y: displays.y
    width: root.inset + root.span - x
    label: Recorder.recording ? "Recording" : "Record"
    glyph: Recorder.recording ? Icons.stop : Icons.record
    sublabel: Recorder.status
    active: Recorder.busy
    current: root.keyboardIndex === 7
    onToggled: {
      if (Recorder.busy)
        Recorder.stop();
      else
        root.recorderRequested();
    }
  }

  // Opens the arrangement either way: there is nothing for its badge to switch.
  Tile {
    id: displays

    x: root.inset
    y: bluetooth.y + Theme.controlTileHeight + Theme.controlTileGap
    width: root.thirdWidth
    label: "Displays"
    glyph: Icons.monitor
    sublabel: Displays.external ? Displays.count + (Displays.count === 1 ? " display" : " displays") : "Built-in"
    current: root.keyboardIndex === 5
    opensView: true
    onToggled: root.opened("displays")
    onOpened: root.opened("displays")
  }

  // Every press steps Fast, Standard, Long life: three states have no switch to flip, so the
  // badge and the body do the same. Long life is lit, the one mode that limits the charge.
  Tile {
    id: charge

    x: displays.x + displays.width + Theme.controlTileGap
    y: displays.y
    width: root.thirdWidth
    label: "Charging"
    glyph: {
      switch (ChargeMode.mode) {
      case "Fast":
        return IconPaths.zap;
      case "Long_Life":
        return IconPaths.leaf;
      default:
        return IconPaths.battery;
      }
    }
    sublabel: ChargeMode.available ? ChargeMode.label : "Unavailable"
    active: ChargeMode.limiting
    current: root.keyboardIndex === 6
    enabled: ChargeMode.available
    accessibleName: "Charging mode"
    Accessible.role: Accessible.Button
    Accessible.checkable: false
    Accessible.description: ChargeMode.limiting ? "Long life: stops charging at about 80 % to preserve the battery" : ChargeMode.label
    onToggled: ChargeMode.cycle()
  }

  VolumeRow {
    x: root.inset
    y: root.slidersTop
    levelKey: "level.volume"
    width: root.span
    showMute: false
    node: root.sink
  }

  BigSlider {
    x: root.inset
    y: root.slidersTop + Theme.controlSliderHeight + Theme.controlSliderGap
    morphKey: "level.brightness"
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

  SectionLabel {
    x: root.inset
    y: root.sectionTop
    width: root.span
    verticalAlignment: Qt.AlignTop
    title: "Notifications"
    action: root.live > 0 ? "Clear all" : ""
    onActionClicked: root.clearNotifications()
  }

  // Crosses with the rows on their own clock: a spring at the slots' pace, read from the other
  // end, so it is gone as the first row starts to show and comes up as the last one clears, and
  // the two are never read through each other.
  Text {
    x: root.inset + 1
    y: root.listTop + 12
    visible: opacity > 0
    opacity: Motion.ramp(empty.value, 1 - Theme.listSlotFade, 1)
    text: "Nothing new"
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize

    ProgressSpring {
      id: empty

      target: root.live === 0 ? 1 : 0
      omega: Theme.listSlotOmega
      damping: 1
    }
  }

  ScrollView {
    id: notifications

    name: "notifications"

    x: root.inset
    y: root.listTop
    width: root.span
    height: root.listHeight
    visible: root.count > 0

    // The rows' own height: every slot carries the gap under it, so the last one's is taken off.
    Item {
      id: list

      width: notifications.width
      implicitHeight: Math.max(0, slots.height - Theme.controlNotifGap)
      height: implicitHeight

      Column {
        id: slots

        width: list.width

        Repeater {
          id: history

          model: NotificationStore.history

          // A row's place in the list. The slot, not the card, is what opens and closes: its
          // height and opacity ride one spring, so a new row grows open as it fades in, one that
          // goes fades as it collapses, and the rows below move on the same clock. The card inside
          // is left alone, so the collapse works wherever the card is (dragged aside, faded).
          //
          // dismiss() is the one way out: the card's X calls it, and so can anything else that
          // takes a row away (a swipe). The row leaves the store when its slot has shut.
          Item {
            id: slot

            required property int index

            // Rows are snapshots that never change, so a one-shot read is enough.
            readonly property var row: NotificationStore.history.get(index)

            // True from dismiss() until the slot has shut and the row is gone.
            property bool leaving: false
            // False for the first frame of a row that arrives, so it opens from nothing; a row
            // already there when the view is built is placed open.
            property bool born: false
            // This row is in root.going.
            property bool counted: false
            readonly property alias card: card

            function dismiss() {
              if (slot.leaving)
                return;
              slot.leaving = true;
              slot.counted = true;
              root.going++;
              // Motion off: the spring has already landed, so nothing else would finish it.
              if (!open.running)
                later.start();
            }

            function finish() {
              // Uncounted first, so the rows staying are never counted one short.
              slot.counted = false;
              root.going--;
              NotificationStore.dismiss(slot.index);
            }

            Component.onCompleted: {
              if (root.primed) {
                later.start();
              } else {
                open.animate = false;
                slot.born = true;
                open.animate = true;
              }
            }
            Component.onDestruction: {
              if (slot.counted)
                root.going--;
            }

            width: list.width
            height: (card.height + Theme.controlNotifGap) * open.value
            opacity: Motion.ramp(open.value, Theme.listSlotFade, 1)
            // Only while it moves: the card's own edge is the slot's at rest.
            clip: open.value < 1

            // The next turn of the event loop: a row that arrives opens from the frame it was
            // placed shut in, and one that has shut is taken away once its spring's own step is
            // over (taking it away inside that step would pull the spring from under itself).
            Timer {
              id: later

              interval: 0
              onTriggered: {
                if (slot.leaving)
                  slot.finish();
                else
                  slot.born = true;
              }
            }

            ProgressSpring {
              id: open

              target: slot.born && !slot.leaving ? 1 : 0
              omega: Theme.listSlotOmega
              damping: 1
              onRunningChanged: {
                if (!running && slot.leaving)
                  later.start();
              }
            }

            NotificationCard {
              id: card

              width: slot.width
              enabled: !slot.leaving
              appName: slot.row ? slot.row.appName : ""
              summary: slot.row ? slot.row.summary : ""
              body: slot.row ? slot.row.body : ""
              image: slot.row ? slot.row.image : ""
              appIcon: slot.row ? slot.row.appIcon : ""
              desktopEntry: slot.row ? slot.row.desktopEntry : ""
              urgent: slot.row ? slot.row.urgent : false
              onDismissed: slot.dismiss()

              // Dragged or thrown sideways, either way, the row follows the hand and goes: the
              // card leaves first, then the slot shuts on what is left, as it does for the X.
              x: swipe.offset
              opacity: swipe.fade

              SwipeAway {
                id: swipe

                name: "history." + slot.index
                onDismissed: slot.dismiss()
              }
            }
          }
        }
      }
    }
  }
}
