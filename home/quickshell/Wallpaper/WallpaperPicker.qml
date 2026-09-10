import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The wallpaper picker. Board 08, and the island's fifth shape.
//
// Like the launcher and the control centre it is not a panel: it starts at the
// pill's own size, radius and centre line and grows in its place, and the bar
// stands its island down for as long as it is on screen.
//
// The source recording settles the shape and the motion. Between 3:58 and 4:05
// the picker grows from a 118 px pill - the island's own idle width, to the
// pixel - out to 1008 by 231, from a top edge that never moves. Its width and
// its height ride one curve: sampled frame by frame at 60 fps, the two tracks
// agree on their progress at every frame to within 1.5% of their travel. The
// duration is Theme.morphWallpaper; see the note there for the one thing the
// source does that this does not.
//
// What it carries is one row of previews, clipped by the panel rather than
// wrapped into a grid, so a collection larger than the row runs on past both
// edges. The row is the whole surface: there is no scrollbar, no page and no
// second line, and the count in the footer is what says how much of it is out
// of sight.
Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    property bool open: false

    // Which wallpaper the ring is on. Not the one that is up: that is
    // Wallpapers.index, and the two are the same only until the first key.
    property int selected: 0

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

    readonly property var entries: Wallpapers.entries
    readonly property int count: entries.length

    // True from the moment the shape starts growing until it is back to pill
    // size - or until the frozen still it left for a taker is taken down -
    // which is the whole time the bar must keep its island hidden.
    readonly property bool showing: open || origin.held || surface.width > origin.collapsedWidth + 0.5

    // The room the row has, and the room it wants. Everything about where the
    // row sits comes out of these two.
    readonly property real inner: Theme.wallpaperWidth - 2 * Theme.wallpaperInset

    // The selected tile takes the first width, everything else the last. The
    // list is indexed by distance from the selection and clamped to its end, so
    // a longer list would ramp; see the note on the token.
    function tileWidth(i) {
      var widths = Theme.wallpaperTileWidths;
      var d = Math.abs(i - win.selected);
      return widths[Math.min(d, widths.length - 1)];
    }

    function tileHeight(i) {
      return Math.round(win.tileWidth(i) / Theme.wallpaperTileAspect);
    }

    // Tiles are laid out left to right on a gap, so a tile's left edge is
    // everything before it. Sizes change with the selection, which means every
    // tile's position does too - which is the point: choosing the tile to the
    // right pushes the row left as that tile grows.
    function tileX(i) {
      var x = 0;
      for (var j = 0; j < i; j++)
        x += win.tileWidth(j) + Theme.wallpaperTileGap;
      return x;
    }

    readonly property real stripWidth: count > 0 ? win.tileX(count) - Theme.wallpaperTileGap : 0

    // A row that fits is centred and stays put. A row that does not is pulled
    // so the selection sits on the panel's centre line, and then held back so
    // neither end can come in past the inset and leave a gap at the edge of a
    // row that has more to show.
    readonly property real stripX: {
      if (stripWidth <= inner)
        return Theme.wallpaperInset + (inner - stripWidth) / 2;

      var wanted = Theme.wallpaperWidth / 2 - (win.tileX(win.selected) + win.tileWidth(win.selected) / 2);
      var furthest = Theme.wallpaperWidth - Theme.wallpaperInset - stripWidth;
      return Math.max(furthest, Math.min(Theme.wallpaperInset, wanted));
    }

    function show() {
      // Open on what is actually up, so the first thing the ring says is where
      // the current wallpaper sits among the others.
      Wallpapers.refresh();
      selected = Math.max(0, Wallpapers.index);
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it.
      handover = false;
      origin.claim(Theme.wallpaperWidth, Theme.wallpaperHeight, Theme.wallpaperRadius, Theme.morphWallpaper);
      Bus.closePanels();
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

    // The row is a ring: stepping past either end comes out at the other. A
    // wallpaper folder has no first or last picture in any sense the user
    // cares about, so stopping dead at an edge only means pressing the other
    // arrow the whole way back. The wrap is worth the one jump it costs the
    // rail, because that jump is also what says the row has run out.
    //
    // The modulo is written to survive a negative delta: JavaScript's % keeps
    // the sign of the left operand, so the count is added back before the
    // second one.
    function step(delta) {
      if (count === 0)
        return;
      selected = ((selected + delta) % count + count) % count;
    }

    // Enter applies and leaves. Nothing here previews: a wallpaper is the one
    // thing on screen that everything else is drawn against, and changing it
    // under every arrow key would repaint the desktop half a dozen times on the
    // way to a choice.
    function activate() {
      if (selected < 0 || selected >= count)
        return;
      Wallpapers.apply(entries[selected]);
      hide();
    }

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Ignore

    // Same focus prime as the launcher and the control centre: Hyprland focuses
    // an OnDemand surface when it first maps, but not when an already-mapped
    // one goes None -> OnDemand, and this surface stays mapped through its
    // close animation.
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
        Bus.wallpaperScreen = win.screen ? win.screen.name : "";
      } else {
        // The close is off screen; the shape Behaviors are live again for
        // the next open. A held still unmaps with handover still raised,
        // which is what keeps its cut to the pill instant.
        win.handover = false;
        if (win.screen && Bus.wallpaperScreen === win.screen.name)
          Bus.wallpaperScreen = "";
      }
    }

    Connections {
      target: Bus

      function onWallpaperToggled() {
        if (win.open)
          win.hide();
        else if (win.focused)
          win.show();
      }

      function onWallpaperClosed() {
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

      // A bar dropdown was asked for. Nothing is growing in this surface's
      // place, so it owes the pill its own animated collapse.
      function onCloseIslands() {
        win.hide();
      }
    }

    // A click anywhere off the surface dismisses. The surface sits on top of
    // this and takes its own clicks.
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

      implicitWidth: win.open ? Theme.wallpaperWidth : origin.held ? origin.heldWidth : origin.originWidth
      implicitHeight: win.open ? Theme.wallpaperHeight : origin.held ? origin.heldHeight : origin.originHeight
      surfaceRadius: win.open ? Theme.wallpaperRadius : origin.held ? origin.heldRadius : origin.originRadius

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
          // h and l alongside the arrows, because a row is a row.
          case Qt.Key_Left:
          case Qt.Key_Up:
          case Qt.Key_H:
          case Qt.Key_Backtab:
            win.step(-1);
            break;
          case Qt.Key_Right:
          case Qt.Key_Down:
          case Qt.Key_L:
          case Qt.Key_Tab:
            win.step(1);
            break;
          case Qt.Key_Home:
            win.selected = 0;
            break;
          case Qt.Key_End:
            win.selected = Math.max(0, win.count - 1);
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

      // The carried-over clock; see Ui/IslandClock.qml.
      IslandClock {
        anchors.fill: parent
        origin: origin
        shown: !win.open && !origin.held
      }

      // Everything the picker draws, cross-faded against the clock on the short
      // clock the island uses for its own contents. Nothing inside fades on its
      // own; the growing shape uncovers it.
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

        Text {
          x: Theme.wallpaperInset
          y: Theme.wallpaperTitleTop
          text: "Wallpaper"
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.wallpaperTitleSize
          font.weight: Font.Medium
        }

        // The palette the shell is wearing, which is the other half of what a
        // wallpaper is being chosen for.
        Text {
          x: Theme.wallpaperWidth - Theme.wallpaperInset - width
          y: Theme.wallpaperMetaTop
          text: Theme.paletteName
          color: Theme.subtle
          font.family: Theme.uiFont
          font.pixelSize: Theme.wallpaperMetaSize
        }

        // Clipped to the panel rather than to the inset, so a row longer than
        // the panel is cut by the panel's own edge and reads as running on
        // past it.
        Item {
          id: strip

          x: 0
          y: 0
          width: Theme.wallpaperWidth
          height: Theme.wallpaperHeight
          clip: true

          Item {
            id: rail

            x: win.stripX
            y: 0
            width: win.stripWidth
            height: parent.height

            Behavior on x {
              Morph {
                duration: Theme.morphDuration
              }
            }

            Repeater {
              model: win.entries

              WallpaperTile {
                id: tile

                required property int index
                required property var modelData

                x: win.tileX(index)
                y: Theme.wallpaperRowMid - height / 2
                width: win.tileWidth(index)
                height: win.tileHeight(index)
                source: "file://" + modelData.real
                selected: index === win.selected
                active: index === Wallpapers.index

                // Every tile travels and resizes on the one curve, which is
                // what keeps the gaps between them constant while they do: a
                // tile's left edge is the sum of the widths before it, and a
                // sum of identical eases is the same ease of the sum.
                Behavior on x {
                  Morph {
                    duration: Theme.morphDuration
                  }
                }

                Behavior on width {
                  Morph {
                    duration: Theme.morphDuration
                  }
                }

                Behavior on height {
                  Morph {
                    duration: Theme.morphDuration
                  }
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
          }
        }

        // The footer says where the choice came from and where it sits. The
        // directory is dimmed and the file name is not, so the name reads at a
        // glance and the path is there to be looked at rather than read.
        Text {
          id: directory

          x: Theme.wallpaperInset
          y: Theme.wallpaperFooterTop
          text: Wallpapers.directoryLabel
          color: Theme.muted
          font.family: Theme.monoFont
          font.pixelSize: Theme.wallpaperMetaSize
        }

        Text {
          x: directory.x + directory.width
          y: Theme.wallpaperFooterTop
          text: win.selected >= 0 && win.selected < win.count ? win.entries[win.selected].name : ""
          color: Theme.subtle
          font.family: Theme.monoFont
          font.pixelSize: Theme.wallpaperMetaSize
          font.weight: Font.DemiBold
        }

        Text {
          x: Theme.wallpaperWidth - Theme.wallpaperInset - width
          y: Theme.wallpaperFooterTop
          text: win.count > 0 ? (win.selected + 1) + " / " + win.count + "   ·   Enter to apply" : "No wallpapers in this folder"
          color: Theme.muted
          font.family: Theme.uiFont
          font.pixelSize: Theme.wallpaperMetaSize
        }
      }
    }
  }
}
