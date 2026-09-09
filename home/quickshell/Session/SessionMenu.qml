import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power menu. Board 11, and the island in another of its shapes.
//
// It was a dimmed screen with a column of words down the middle. The board
// makes it what every other surface here is: the pill grows in place into a
// short wide card carrying one row of tiles, on the 339 ms the board's own
// motion table gives for an island-to-surface morph, and shrinks back into the
// pill when it is done. Nothing dims; the menu is a surface, not a mode.
//
// Lock acts on the first press. The two that end the session do not: one press
// arms the tile, which turns love and relabels itself Confirm, and only a
// second press on the same tile commits. Moving to another tile disarms the
// first, so an armed tile is never left behind for a later keystroke to fire.
Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    property bool open: false

    // Which tile the keyboard is on.
    property int current: 0

    // Which tile is armed, or -1. Only ever one, and only ever one that asks
    // to be.
    property int armed: -1

    property bool handover: false

    readonly property bool focused: Monitors.isFocused(win.screen)

    readonly property int collapsedWidth: Media.active ? Theme.islandPlayingWidth : Theme.islandIdleWidth

    // Lock is done the moment it is pressed; there is nothing to undo. The
    // other two take the session with them, so they ask first.
    readonly property var tiles: [
      {
        glyph: Icons.lock,
        label: "Lock",
        confirms: false
      },
      {
        glyph: Icons.reboot,
        label: "Restart",
        confirms: true
      },
      {
        glyph: Icons.shutdown,
        label: "Power Off",
        confirms: true
      }
    ]

    readonly property int count: tiles.length

    readonly property int openWidth: Theme.powerInset * 2 + count * Theme.powerTileWidth + (count - 1) * Theme.powerTileGap

    readonly property bool showing: open || surface.width > collapsedWidth + 0.5

    function tileX(i) {
      return Theme.powerInset + i * (Theme.powerTileWidth + Theme.powerTileGap);
    }

    function show() {
      current = 0;
      armed = -1;
      handover = false;
      Bus.islandClaimed();
      Bus.closePanels();
      open = true;
    }

    function hide() {
      open = false;
    }

    function dismiss() {
      handover = true;
      open = false;
    }

    // Moving disarms. An armed tile that stayed armed while the selection moved
    // away would sit there waiting for a Return meant for something else.
    function move(delta) {
      armed = -1;
      current = (current + delta + count) % count;
    }

    function activate(i) {
      current = i;

      if (tiles[i].confirms && armed !== i) {
        armed = i;
        return;
      }

      win.hide();

      switch (i) {
      case 0:
        Bus.lockRequested();
        break;
      case 1:
        systemctl.command = ["systemctl", "reboot"];
        systemctl.running = true;
        break;
      case 2:
        systemctl.command = ["systemctl", "poweroff"];
        systemctl.running = true;
        break;
      }
    }

    Process {
      id: systemctl
    }

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-session"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Ignore

    // Same focus prime as every other surface that grows out of the island:
    // Hyprland focuses an OnDemand surface when it first maps, but not when an
    // already-mapped one goes None -> OnDemand, and this one stays mapped
    // through its close.
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
        armed = -1;
      }
    }

    onShowingChanged: {
      if (showing)
        Bus.sessionScreen = win.screen ? win.screen.name : "";
      else if (win.screen && Bus.sessionScreen === win.screen.name)
        Bus.sessionScreen = "";
    }

    Connections {
      target: Bus

      function onSessionToggled() {
        if (win.open)
          win.hide();
        else if (win.focused)
          win.show();
      }

      function onIslandClaimed() {
        if (win.open)
          win.dismiss();
      }
    }

    // A click anywhere off the surface dismisses, which is also how an armed
    // tile is stood down without committing to it.
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

      implicitWidth: win.open ? win.openWidth : win.collapsedWidth
      implicitHeight: win.open ? Theme.powerHeight : Theme.barHeight
      surfaceRadius: win.open ? Theme.powerRadius : Theme.islandRadius

      Behavior on implicitWidth {
        enabled: !win.handover

        Morph {
          duration: Theme.morphSurface
        }
      }

      Behavior on implicitHeight {
        enabled: !win.handover

        Morph {
          duration: Theme.morphSurface
        }
      }

      Behavior on surfaceRadius {
        enabled: !win.handover

        Morph {
          duration: Theme.morphSurface
        }
      }

      Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
          switch (event.key) {
          case Qt.Key_Escape:
            // The first Escape stands an armed tile down; the second closes.
            if (win.armed >= 0)
              win.armed = -1;
            else
              win.hide();
            break;
          case Qt.Key_Left:
          case Qt.Key_H:
          case Qt.Key_Backtab:
            win.move(-1);
            break;
          case Qt.Key_Right:
          case Qt.Key_L:
          case Qt.Key_Tab:
            win.move(1);
            break;
          case Qt.Key_Return:
          case Qt.Key_Enter:
          case Qt.Key_Space:
            win.activate(win.current);
            break;
          default:
            return;
          }
          event.accepted = true;
        }
      }

      SystemClock {
        id: clock

        precision: SystemClock.Minutes
      }

      // The clock belongs to neither state, and stays in the growing box until
      // the tiles have taken over.
      Text {
        x: (surface.width - width) / 2
        y: (surface.height - height) / 2
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandClockSize
        font.weight: Font.DemiBold
        opacity: win.open ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent
          }
        }
      }

      Item {
        id: body

        anchors.fill: parent
        opacity: win.open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent
          }
        }

        Repeater {
          model: win.tiles

          Item {
            id: tile

            required property int index
            required property var modelData

            readonly property bool isArmed: win.armed === tile.index
            readonly property bool isCurrent: win.current === tile.index

            x: win.tileX(index)
            y: Theme.powerTileTop
            width: Theme.powerTileWidth
            height: Theme.powerTileHeight

            Rectangle {
              anchors.fill: parent
              radius: Theme.powerTileRadius
              // Armed, the tile is filled love and carries its own text in the
              // base colour: the one thing on screen that is about to do
              // something irreversible looks nothing like the things that are
              // not.
              color: tile.isArmed ? Theme.love : Theme.withAlpha(Theme.highlightLow, Theme.powerTileFillAlpha)
              border.width: 1
              border.color: {
                if (tile.isArmed)
                  return Theme.love;
                if (tile.isCurrent || hover.containsMouse)
                  return Theme.accent;
                return Theme.withAlpha(Theme.highlightMed, Theme.powerTileBorderAlpha);
              }

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animFast
                }
              }

              Behavior on border.color {
                ColorAnimation {
                  duration: Theme.animFast
                }
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              y: Theme.powerGlyphTop - Theme.powerTileTop - height / 2 + Theme.powerGlyphSize / 2
              text: tile.modelData.glyph
              color: tile.isArmed ? Theme.base : Theme.text
              font.family: Theme.iconFont
              font.pixelSize: Theme.powerGlyphSize
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              y: Theme.powerLabelTop - Theme.powerTileTop
              text: tile.isArmed ? "Confirm" : tile.modelData.label
              color: tile.isArmed ? Theme.base : Theme.text
              font.family: Theme.uiFont
              font.pixelSize: Theme.powerLabelSize
              font.weight: tile.isArmed ? Font.Bold : Font.Medium
            }

            MouseArea {
              id: hover

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              // Hovering moves the keyboard's place too, so the tile the eye is
              // on and the tile Return would fire are never different ones.
              onEntered: if (win.armed < 0)
                win.current = tile.index
              onClicked: win.activate(tile.index)
            }
          }
        }
      }
    }
  }
}
