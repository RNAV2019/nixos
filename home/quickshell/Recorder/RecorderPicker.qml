import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Control
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

    function back() {
      if (win.returnTo === "control")
        Bus.toggleSurface("control");
      else
        win.hide();
    }

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

    onKeyPressed: function (event) {
      switch (event.key) {
      case Qt.Key_Left:
      case Qt.Key_H:
      case Qt.Key_Backtab:
        win.step(-1);
        break;
      case Qt.Key_Right:
      case Qt.Key_L:
      case Qt.Key_Tab:
        win.step(1);
        break;
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
      case Qt.Key_Return:
      case Qt.Key_Enter:
        win.activate();
        break;
      case Qt.Key_Escape:
      case Qt.Key_Backspace:
        win.back();
        break;
      default:
        return;
      }
      event.accepted = true;
    }

    Item {
      id: body

      anchors.fill: parent

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

        Item {
          id: row

          required property int index
          required property var modelData

          readonly property bool value: win.rowValue(modelData.key)

          x: Theme.recorderInset
          y: Theme.recorderRowsTop + index * (Theme.recorderRowHeight + Theme.recorderRowGap)
          width: Theme.recorderWidth - Theme.recorderInset * 2
          height: Theme.recorderRowHeight

          Rectangle {
            anchors.fill: parent
            radius: Theme.recorderRowRadius
            color: Theme.withAlpha(Theme.highlightLow, Theme.powerTileFillAlpha)
          }

          Text {
            x: Theme.recorderRowTextLeft
            y: (parent.height - height) / 2
            text: row.modelData.label
            color: row.value ? Theme.text : Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: Theme.recorderRowLabelSize
            font.weight: Theme.weightMedium
          }

          Switch {
            x: parent.width - width - Theme.recorderRowTextLeft
            y: (parent.height - height) / 2
            checked: row.value
            onToggled: function (value) {
              win.setRow(row.modelData.key, value);
            }
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: win.setRow(row.modelData.key, !row.value)
            z: -1
          }
        }
      }

      // The frame-rate row: the toggles' shape with three pills where a switch would sit.
      // A muted 120 takes no clicks, and the row cycles through what is live here.
      Item {
        id: fpsRow

        x: Theme.recorderInset
        y: Theme.recorderRowsTop + 3 * (Theme.recorderRowHeight + Theme.recorderRowGap)
        width: Theme.recorderWidth - Theme.recorderInset * 2
        height: Theme.recorderRowHeight

        Rectangle {
          anchors.fill: parent
          radius: Theme.recorderRowRadius
          color: Theme.withAlpha(Theme.highlightLow, Theme.powerTileFillAlpha)
        }

        Text {
          x: Theme.recorderRowTextLeft
          y: (parent.height - height) / 2
          text: "Frame rate"
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.recorderRowLabelSize
          font.weight: Theme.weightMedium
        }

        Row {
          x: parent.width - width - Theme.recorderRowTextLeft
          y: (parent.height - height) / 2
          spacing: Theme.recorderFpsSegmentGap

          Repeater {
            model: [30, 60, 120]

            Rectangle {
              id: segment

              required property int modelData

              readonly property bool active: win.effectiveFps === segment.modelData
              readonly property bool live: segment.modelData !== 120 || win.fps120Live

              width: Theme.recorderFpsSegmentWidth
              height: Theme.recorderFpsSegmentHeight
              radius: height / 2
              opacity: segment.live ? 1 : 0.4
              color: segment.active ? Theme.accentFill : hover.containsMouse ? Theme.withAlpha(Theme.highlightMed, Theme.powerTileFillAlpha) : "transparent"

              Behavior on color {
                Tint {}
              }

              Text {
                anchors.centerIn: parent
                text: segment.modelData
                color: segment.active ? Theme.inkOnAccent : Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: Theme.recorderRowLabelSize
                font.weight: segment.active ? Font.Bold : Font.Medium

                Behavior on color {
                  Tint {}
                }
              }

              MouseArea {
                id: hover

                anchors.fill: parent
                enabled: segment.live
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.chooseFps(segment.modelData)
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          cursorShape: Qt.PointingHandCursor
          onClicked: win.cycleFps()
          z: -1
        }
      }
    }
  }
}
