import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The power profiles card. Board 04b, and the island in another shape.
//
// Built on the same plan as the power menu: not a panel, but the island
// itself in another shape. It starts at the pill's own size, radius and
// centre line and grows in its place on the power menu's own morph, and
// shrinks back into the pill when it is done. The tile grid is the power
// menu's and the recorder picker's, to the pixel - three surfaces that ask
// "which of these three" do not ask it in three different shapes.
//
// Where the power menu arms before it commits, this card commits at once:
// a profile switch is instant and reversible, so there is nothing to confirm
// and nothing to stand down. Choosing is the power menu's commit without the
// arm: the tile takes the profile, the card melts back into the pill on the
// same curve it grew out of it, and the bar's island comes back.
//
// The active tile is love, per the board: it is the one thing on screen that
// says the machine's whole stance has changed, and it must not read as one
// more thing that is merely on.
Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    property bool open: false

    // Which tile the keyboard is on.
    property int current: 0

    // Raised while the island is being handed to another surface. While the
    // handover's still is held, this surface's shape rides the taker's own
    // morph; handover is also what keeps the final cut to the pill - once
    // the still is taken down, covered by the taker - instant. See
    // Ui/IslandOrigin.qml.
    property bool handover: false

    // The shape this surface grows out of, and the handover protocol it
    // follows when another surface takes the island: adopt the island's
    // card, claim, take the shape the holder was wearing. One of these for
    // each of the surfaces that stand in for the island.
    IslandOrigin {
      id: origin

      window: win
    }

    readonly property bool focused: Monitors.isFocused(win.screen)

    readonly property var tiles: [
      {
        key: "performance",
        label: "Performance",
        glyph: Icons.bolt
      },
      {
        key: "balanced",
        label: "Balanced",
        glyph: Icons.contrast
      },
      {
        key: "power-saver",
        label: "Power Saver",
        glyph: Icons.batterySaver
      }
    ]

    readonly property int count: tiles.length

    readonly property int openWidth: Theme.recorderInset * 2 + count * Theme.recorderTileWidth + (count - 1) * Theme.recorderTileGap

    readonly property bool showing: open || origin.held || surface.width > origin.collapsedWidth + 0.5

    function tileX(i) {
      return Theme.recorderInset + i * (Theme.recorderTileWidth + Theme.recorderTileGap);
    }

    function show() {
      current = Math.max(0, ["performance", "balanced", "power-saver"].indexOf(PowerProfiles.profile));
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it.
      handover = false;
      origin.claim(win.openWidth, Theme.powerHeight, Theme.recorderRadius, Theme.morphSurface);
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

    // Moving never commits, so unlike the power menu there is nothing to
    // disarm.
    function move(delta) {
      current = (current + delta + count) % count;
    }

    // Commit closes the card first and switches second, on the power menu's
    // ordering: the shape leaves before the work happens, so the eye never
    // sees the card linger over a change already made.
    function activate(i) {
      current = i;
      if (!PowerProfiles.available)
        return;
      win.hide();
      PowerProfiles.set(win.tiles[i].key);
    }

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-profiles"

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
      }
    }

    onShowingChanged: {
      if (showing) {
        Bus.profilesScreen = win.screen ? win.screen.name : "";
      } else {
        // The close is off screen; the shape Behaviors are live again for
        // the next open. A held still unmaps with handover still raised,
        // which is what keeps its cut to the pill instant.
        win.handover = false;
        if (win.screen && Bus.profilesScreen === win.screen.name)
          Bus.profilesScreen = "";
      }
    }

    Connections {
      target: Bus

      function onProfilesToggled() {
        if (win.open)
          win.hide();
        else if (win.focused)
          win.show();
      }

      function onProfilesClosed() {
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

    // A click anywhere off the surface dismisses.
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

      implicitWidth: win.open ? win.openWidth : origin.held ? origin.heldWidth : origin.originWidth
      implicitHeight: win.open ? Theme.powerHeight : origin.held ? origin.heldHeight : origin.originHeight
      surfaceRadius: win.open ? Theme.recorderRadius : origin.held ? origin.heldRadius : origin.originRadius

      Behavior on implicitWidth {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphSurface
        }
      }

      Behavior on implicitHeight {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphSurface
        }
      }

      Behavior on surfaceRadius {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphSurface
        }
      }

      Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
          switch (event.key) {
          case Qt.Key_Escape:
          case Qt.Key_Backspace:
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

      // The carried-over clock; see Ui/IslandClock.qml.
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

        // The daemon's answer is the truth; with nothing answering, the tiles
        // grey out rather than offering a picker that does nothing. A nested
        // item, because the body's own opacity is the open/close fade.
        Item {
          anchors.fill: parent
          opacity: PowerProfiles.available ? 1 : 0.5

          Behavior on opacity {
            Morph {
              duration: Theme.animFast
            }
          }

          Repeater {
            model: win.tiles

          Item {
              id: tile

              required property int index
              required property var modelData

              readonly property bool isActive: PowerProfiles.available && PowerProfiles.profile === tile.modelData.key
              readonly property bool isCurrent: win.current === tile.index

              x: win.tileX(index)
              y: Theme.powerTileTop
              width: Theme.powerTileWidth
              height: Theme.powerTileHeight

              Rectangle {
                anchors.fill: parent
                radius: Theme.powerTileRadius
                // Active, the tile is filled love and carries its own text in
                // the base colour, per the board. The border stays drawn at
                // one pixel so the keyboard's place still reads on the active
                // tile the same way it does on the others.
                color: tile.isActive ? Theme.love : Theme.withAlpha(Theme.highlightLow, Theme.powerTileFillAlpha)
                border.width: 1
                border.color: {
                  if (tile.isCurrent || hover.containsMouse)
                    return Theme.accent;
                  if (tile.isActive)
                    return "transparent";
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
                color: tile.isActive ? Theme.base : Theme.text
                font.family: Theme.iconFont
                font.pixelSize: Theme.powerGlyphSize
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.powerLabelTop - Theme.powerTileTop
                text: tile.modelData.label
                color: tile.isActive ? Theme.base : Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.powerLabelSize
                font.weight: tile.isActive ? Font.Bold : Font.Medium
              }

              MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hovering moves the keyboard's place too, so the tile the eye is
                // on and the tile Return would fire are never different ones.
                onEntered: win.current = tile.index
                onClicked: win.activate(tile.index)
              }
            }
          }
        }
      }
    }
  }
}