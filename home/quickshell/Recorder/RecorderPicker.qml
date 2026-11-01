import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The screen recorder's picker: from the keyboard or pill it grows out of the pill; from
// the control centre the same morph runs backwards, out of that larger shape.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "recorder"
    openWidth: Theme.panelWidth(modelData, Theme.recorderWidth)
    openHeight: Theme.recorderHeight
    openRadius: Theme.recorderRadius

    // Which capture tile the ring is on, seeded from what the recorder was last left on.
    property int selected: 0

    readonly property var targets: [
      {
        key: "screen",
        label: "Screen",
        glyph: Icons.captureScreen
      },
      {
        key: "window",
        label: "Window",
        glyph: Icons.captureWindow
      },
      {
        key: "region",
        label: "Region",
        glyph: Icons.captureRegion
      }
    ]

    readonly property var rows: [
      {
        key: "cursor",
        label: "Mouse cursor"
      },
      {
        key: "desktopAudio",
        label: "Desktop audio"
      },
      {
        key: "microphone",
        label: "Microphone"
      }
    ]

    function rowValue(key) {
      if (key === "cursor")
        return Recorder.cursor;
      if (key === "desktopAudio")
        return Recorder.desktopAudio;
      return Recorder.microphone;
    }

    function setRow(key, value) {
      if (key === "cursor")
        Recorder.cursor = value;
      else if (key === "desktopAudio")
        Recorder.desktopAudio = value;
      else
        Recorder.microphone = value;
    }

    // 120 is only live on an output that can carry it; a 120 remembered from a faster
    // panel reads as the 60 it would have recorded at there.
    readonly property bool fps120Live: Recorder.monitorRefresh >= 120
    readonly property int effectiveFps: Recorder.fps === 120 && !win.fps120Live ? 60 : Recorder.fps

    function chooseFps(value) {
      if (value === 120 && !win.fps120Live)
        return;
      Recorder.fps = value;
    }

    function cycleFps() {
      var rates = win.fps120Live ? [30, 60, 120] : [30, 60];
      win.chooseFps(rates[(rates.indexOf(win.effectiveFps) + 1) % rates.length]);
    }

    onOpening: {
      selected = Math.max(0, ["screen", "window", "region"].indexOf(Recorder.target));
      // Re-ask Hyprland, so a mode change since last open is what gates 120.
      Recorder.refreshMonitor();
      launchPending = false;
      settleCap.stop();
      returnTo = "";
    }

    // Opened from the control centre's Record tile (Bus.recorderFrom names this output for
    // that request), so backing out returns there, as one more handover, instead of
    // shrinking to the pill. A shortcut or IPC open, even one landing while the control centre
    // is still closing, leaves it empty. Starting or clicking away still closes.
    property string returnTo: ""

    function step(delta) {
      selected = ((selected + delta) % 3 + 3) % 3;
    }

    // Closing first, because slurp cannot draw over a surface that still holds the keyboard;
    // the launch then waits for the close to be over and the window parked, so neither the
    // capture nor slurp's overlay catches its tail. Parked, the window also takes the pill's
    // new width (a recording widens it) at once instead of springing back out to it.
    function activate() {
      Recorder.target = win.targets[win.selected].key;
      win.hide();
      launchPending = true;
      settleCap.restart();
      Qt.callLater(win.launchIfSettled);
    }

    property bool launchPending: false

    // Called off a change notification, never inside one: starting widens the pill, which
    // the shape bindings read.
    function launchIfSettled() {
      if (!launchPending || win.open || win.showing || !win.parked)
        return;
      launchPending = false;
      settleCap.stop();
      Recorder.start();
    }

    onParkedChanged: if (parked)
      Qt.callLater(win.launchIfSettled)

    // A backstop only: if the window never parks (a lock mid-close), launch anyway. Not off
    // actionSettleDelay, which is 0 under reduced motion and would beat the 80 ms park.
    Timer {
      id: settleCap

      interval: 2000
      onTriggered: {
        if (!win.launchPending)
          return;
        win.launchPending = false;
        Recorder.start();
      }
    }

    Connections {
      target: Bus

      // Asked for with nothing recording; while something is recording the same key stops it.
      function onRecorderRequested() {
        if (!win.focused || win.open)
          return;
        var fromTile = win.screen !== null && Bus.recorderFrom === win.screen.name;
        win.show();
        // After show(): opening() clears it for every other way in.
        win.returnTo = fromTile ? "control" : "";
      }
    }

    Panel {
      id: panel

      surface: win
      // Back is the control centre this was opened from; opened any other way there is none,
      // and Escape closes.
      backKeys: win.returnTo === "control"
      takesMove: true
      takesTab: true
      takesActivate: true

      onBacked: Bus.toggleSurface("control")
      onMoved: function (dx, dy) {
        win.step(dx + dy);
      }
      onStepped: function (delta) {
        win.step(delta);
      }
      onActivated: win.activate()

      onKeyPressed: function (event) {
        switch (event.key) {
        case Qt.Key_C:
          Recorder.cursor = !Recorder.cursor;
          break;
        case Qt.Key_A:
          Recorder.desktopAudio = !Recorder.desktopAudio;
          break;
        case Qt.Key_M:
          Recorder.microphone = !Recorder.microphone;
          break;
        case Qt.Key_F:
          win.cycleFps();
          break;
        default:
          return;
        }
        event.accepted = true;
      }

      ChoiceTiles {
        inset: Theme.recorderInset
        model: win.targets
        currentIndex: win.selected
        activeIndex: win.selected
        onEntered: win.selected = index
        onActivated: {
          win.selected = index;
          win.activate();
        }
      }

      Repeater {
        model: win.rows

        RecorderRow {
          id: row

          required property int index
          required property var modelData

          readonly property bool value: win.rowValue(modelData.key)

          y: Theme.recorderRowsTop + index * (Theme.recorderRowHeight + Theme.recorderRowGap)
          label: modelData.label
          lit: row.value
          onClicked: win.setRow(modelData.key, !row.value)

          trailing: Switch {
            checked: row.value
            onToggled: function (value) {
              win.setRow(row.modelData.key, value);
            }
          }
        }
      }

      // The frame-rate row: the toggles' shape with three pills where a switch would sit.
      // A muted 120 takes no clicks, and the row cycles through what is live here.
      RecorderRow {
        y: Theme.recorderRowsTop + 3 * (Theme.recorderRowHeight + Theme.recorderRowGap)
        label: "Frame rate"
        onClicked: win.cycleFps()

        trailing: Segmented {
          compact: true
          accessibleName: "Frame rate"
          currentIndex: [30, 60, 120].indexOf(win.effectiveFps)
          segments: [
            {
              "label": "30"
            },
            {
              "label": "60"
            },
            {
              "label": "120",
              "enabled": win.fps120Live
            }
          ]
          onChosen: function (index) {
            win.chooseFps([30, 60, 120][index]);
          }
        }
      }
    }
  }
}
