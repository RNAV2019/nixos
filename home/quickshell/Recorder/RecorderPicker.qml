import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Control
import qs.Ui

// The screen recorder's picker: the island in another shape. From the keyboard or the
// pill it grows out of the pill; from the control centre the same morph runs backwards,
// out of the larger shape that surface was wearing.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "recorder"
    openWidth: Theme.recorderWidth
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

    onOpening: {
      selected = Math.max(0, ["screen", "window", "region"].indexOf(Recorder.target));
    }

    function step(delta) {
      selected = ((selected + delta) % 3 + 3) % 3;
    }

    // Closing first, because slurp cannot draw over a surface that still holds the keyboard.
    function activate() {
      Recorder.target = win.targets[win.selected].key;
      win.hide();
      Qt.callLater(function () {
        Recorder.start();
      });
    }

    Connections {
      target: Bus

      // Asked for with nothing recording; while something is recording the same key stops it.
      function onRecorderRequested() {
        if (win.focused && !win.open)
          win.show();
      }
    }
    onKeyPressed: function (event) {
          switch (event.key) {
          case Qt.Key_Escape:
            win.hide();
            break;
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
          case Qt.Key_Return:
          case Qt.Key_Enter:
            win.activate();
            break;
          default:
            return;
          }
      event.accepted = true;
    }

    Item {
      id: body

      anchors.fill: parent
      opacity: win.open || win.origin.held ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        enabled: !win.origin.held

        Morph {
          duration: Theme.morphContent
        }
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
              font.weight: Font.Medium
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
      }
  }
}
