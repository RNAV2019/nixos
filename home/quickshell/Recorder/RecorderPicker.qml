import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Control
import qs.Ui

// The screen recorder's picker. Board 08, and the island's sixth shape.
//
// Built on the same plan as the launcher, the wallpaper picker and the power
// menu: not a panel, but the island itself in another shape. It starts at the
// pill's own size, radius and centre line and grows in its place, and the bar
// stands its island down for as long as it is on screen.
//
// It is reached two ways and they arrive from opposite directions. From the
// keyboard, or from the pill, it grows out of the pill as everything else on
// this layer does. From the control centre it contracts: that surface is much
// bigger than this card, so the same morph runs backwards, out of the shape
// the control centre was wearing. Either door is the same door now - the
// picker claims the island the way every other surface does, and the claim is
// what stands the holder down - and the card is the same card and lands in
// the same place, which is the point: the user should not be able to tell
// from the result which door they came in by.
Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    property bool open: false

    // Raised while the island is being handed to another surface. While the
    // handover's still is held, this surface's shape rides the taker's own
    // morph; handover is also what keeps the final cut to the pill - once
    // the still is taken down, covered by the taker - instant. See
    // Ui/IslandOrigin.qml.
    property bool handover: false

    // The shape this surface grows out of, and the handover protocol it
    // follows when another surface takes the island: adopt the island's
    // card, claim, take the shape the holder was wearing. One of these for
    // each of the six surfaces that stand in for the island.
    IslandOrigin {
      id: origin

      window: win
    }

    readonly property bool focused: Monitors.isFocused(win.screen)

    readonly property bool showing: open || origin.held || surface.width > origin.collapsedWidth + 0.5

    // Which capture tile the ring is on. Seeded from what the recorder was
    // last left on, so the picker opens on the last answer.
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

    function show() {
      selected = Math.max(0, ["screen", "window", "region"].indexOf(Recorder.target));
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it. Out of the control centre that is
      // the one handover that contracts: this card is much smaller than that
      // panel, so the morph - both this one and the still the panel rides
      // with it - runs backwards out of the box it was wearing.
      handover = false;
      origin.claim(Theme.recorderWidth, Theme.recorderHeight, Theme.recorderRadius, Theme.morphWallpaper);
      open = true;
    }

    function hide() {
      origin.release();
      open = false;
    }

    // Giving the island up to the surface that claimed it. The still this
    // leaves behind is what the eye sees until the taker's first frame
    // lands; see Ui/IslandOrigin.qml.
    function dismiss() {
      origin.publish(surface.width, surface.height, surface.surfaceRadius);
      origin.hold(surface.width, surface.height, surface.surfaceRadius);
      handover = true;
      open = false;
    }

    // The row is a ring, as the wallpaper row is.
    function step(delta) {
      selected = ((selected + delta) % 3 + 3) % 3;
    }

    // Choosing closes first and starts second. A window or a region needs
    // slurp, and slurp cannot draw over a surface that still holds the
    // keyboard, so the picker has to be gone before the recorder begins.
    function activate() {
      Recorder.target = win.targets[win.selected].key;
      win.hide();
      Qt.callLater(function () {
        Recorder.start();
      });
    }

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-recorder"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Ignore

    property bool focusPrimed: false

    WlrLayershell.keyboardFocus: win.open ? (win.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    Timer {
      id: focusPrime

      interval: 75
      onTriggered: win.focusPrimed = true
    }

    onOpenChanged: {
      if (open) {
        focusPrimed = false;
        focusPrime.restart();
        Qt.callLater(function () {
          if (win.open)
            keys.forceActiveFocus();
        });
      } else {
        focusPrime.stop();
        focusPrimed = false;
      }
    }

    onShowingChanged: {
      if (showing) {
        Bus.recorderScreen = win.screen ? win.screen.name : "";
      } else {
        // The close is off screen; the shape Behaviors are live again for
        // the next open. A held still unmaps with handover still raised,
        // which is what keeps its cut to the pill instant.
        win.handover = false;
        if (win.screen && Bus.recorderScreen === win.screen.name)
          Bus.recorderScreen = "";
      }
    }

    Connections {
      target: Bus

      // Asked for with nothing recording. While something is recording the
      // same key stops it, which the recorder handles without a surface.
      function onRecorderRequested() {
        if (win.focused && !win.open)
          win.show();
      }

      function onRecorderToggled() {
        if (win.open)
          win.hide();
        else if (win.focused)
          Recorder.toggle();
      }

      function onRecorderClosed() {
        win.hide();
      }

      // Another surface taking the island takes it from here. On this
      // output it is growing in this surface's place, so this one cuts;
      // on any other output nothing is growing here, so this one takes
      // its own close.
      function onIslandClaimed(screen) {
        if (!win.open)
          return;
        if (win.screen && screen === win.screen.name)
          win.dismiss();
        else
          win.hide();
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: win.open
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: win.hide()
    }

    FrostedSurface {
      id: surface

      x: (win.width - width) / 2
      y: Theme.barMarginTop

      clipContent: true

      implicitWidth: win.open ? Theme.recorderWidth : origin.held ? origin.heldWidth : origin.originWidth
      implicitHeight: win.open ? Theme.recorderHeight : origin.held ? origin.heldHeight : origin.originHeight
      surfaceRadius: win.open ? Theme.recorderRadius : origin.held ? origin.heldRadius : origin.originRadius

      Behavior on implicitWidth {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphWallpaper
        }
      }

      Behavior on implicitHeight {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphWallpaper
        }
      }

      Behavior on surfaceRadius {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphWallpaper
        }
      }

      Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
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
          // The three toggles, on the initials of what they carry.
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
      }

      // The carried-over clock; see Ui/IslandClock.qml. Out of the control
      // centre this surface is open while it contracts, so the clock stays
      // hidden: a card that contracted out of the control centre never had a
      // clock on it.
      IslandClock {
        anchors.fill: parent
        origin: origin
        shown: !win.open && !origin.held
      }

      Item {
        id: body

        anchors.fill: parent
        opacity: win.open || origin.held ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          enabled: !origin.held

          Morph {
            duration: Theme.morphContent
          }
        }

        // The capture row, on the power menu's grid.
        Repeater {
          model: win.targets

          Item {
            id: tile

            required property int index
            required property var modelData

            readonly property bool chosen: index === win.selected

            x: Theme.recorderInset + index * (Theme.recorderTileWidth + Theme.recorderTileGap)
            y: Theme.recorderTileTop
            width: Theme.recorderTileWidth
            height: Theme.recorderTileHeight

            Rectangle {
              anchors.fill: parent
              radius: Theme.recorderTileRadius
              color: tile.chosen ? Theme.accent : Theme.withAlpha(Theme.highlightLow, Theme.powerTileFillAlpha)
              border.width: tile.chosen ? 0 : 1
              border.color: Theme.withAlpha(Theme.highlightMed, Theme.powerTileBorderAlpha)

              Behavior on color {
                ColorAnimation {
                  duration: Theme.morphContent
                }
              }
            }

            Text {
              x: (parent.width - width) / 2
              y: Theme.recorderGlyphTop - Theme.recorderTileTop
              text: tile.modelData.glyph
              color: tile.chosen ? Theme.base : Theme.text
              font.family: Theme.iconFont
              font.pixelSize: Theme.recorderGlyphSize
            }

            Text {
              x: (parent.width - width) / 2
              y: Theme.recorderTileLabelTop - Theme.recorderTileTop
              text: tile.modelData.label
              color: tile.chosen ? Theme.base : Theme.text
              font.family: Theme.uiFont
              font.pixelSize: Theme.recorderTileLabelSize
              font.weight: tile.chosen ? Font.Bold : Font.Medium
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                win.selected = tile.index;
                win.activate();
              }
            }
          }
        }

        // The toggles.
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
              // A toggle that is off says so in the muted ink, so the card can
              // be read at a glance without following three switches.
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
}
