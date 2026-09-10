import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The app launcher, and the island in its second shape.
//
// It is not a panel. Panels open below the bar as a separate card; this one
// takes the island's own place, starting at the pill's exact size, radius and
// centre line and growing down into a 520 px column. The bar stands its island
// down for as long as this surface is on screen, so what the eye follows is a
// single shape changing rather than one surface swapping for another.
//
// The open was measured against the source recording frame by frame at 60 fps.
// The shape travels for 308 ms and stops dead, and its width and height ride
// one curve: fitting them separately lands on 306 and 310 ms, so a single
// driver is what the source has too. The shape of that curve is already
// Theme.morphCurve, which tracks the measurements to within 2% of their travel
// - closer than a true critically damped response manages, which undershoots
// the first three frames and then arrives late.
//
// The clock is the one thing the two states share: it stays drawn in the
// growing box and fades as the search row takes over, the same hand-off the
// island performs when it opens into its media card.
//
// The panel is clipped, so the rows do not fade in on the open: they are laid
// out at their final positions from the first frame and the growing shape
// uncovers them. Reflow while typing is the part that animates, and it does
// what the recording shows - new matches fade in, dropped matches fade out,
// and the ones that survive slide to their new places, passing each other on
// the way rather than pushing.
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
    // follows when another surface takes the island: adopt the island's card,
    // claim, take the shape the holder was wearing. One of these for each of
    // the six surfaces that stand in for the island.
    IslandOrigin {
      id: origin

      window: win
    }

    readonly property bool focused: Monitors.isFocused(win.screen)

    // An empty result set still owns a row's worth of height, so the panel has
    // somewhere to say that nothing matched.
    readonly property int rowCount: Math.max(1, Math.min(AppSearch.results.length, Theme.launcherMaxRows))
    readonly property int listHeight: rowCount * (Theme.launcherRowHeight + Theme.launcherRowGap) - Theme.launcherRowGap
    readonly property int openHeight: Theme.launcherListTop + listHeight + Theme.launcherPadBottom

    // True from the moment the shape starts growing until it is back to pill
    // size - or until the frozen still it left for a taker is taken down -
    // which is the whole time the bar must keep its island hidden.
    readonly property bool showing: open || origin.held || surface.width > origin.collapsedWidth + 0.5

    function show() {
      query.text = "";
      list.currentIndex = 0;
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it.
      handover = false;
      origin.claim(Theme.launcherWidth, win.openHeight, Theme.launcherRadius, Theme.morphLauncher);
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

    function activate() {
      if (list.currentIndex < 0 || list.currentIndex >= rows.count)
        return;
      AppSearch.launch(rows.get(list.currentIndex).entryId);
      hide();
    }

    // Rebuild the model in place rather than replacing it, so the list keeps
    // its delegates across a query change and can animate what happened to
    // each one. A wholesale reset would give every row a new delegate at its
    // new position, and the reflow would read as a cut.
    function syncRows() {
      var want = AppSearch.results;
      var i, j;

      // An unfiltered query is the whole application list, so the sweep for
      // rows that no longer belong goes through a lookup rather than a scan.
      var wanted = {};
      for (i = 0; i < want.length; i++)
        wanted[want[i].id] = true;

      for (i = rows.count - 1; i >= 0; i--) {
        if (!wanted[rows.get(i).entryId])
          rows.remove(i);
      }

      // What survives is already in the right relative order, so this scan
      // finds its match at or just after the position it is looking to fill.
      for (i = 0; i < want.length; i++) {
        var at = -1;
        for (j = i; j < rows.count; j++) {
          if (rows.get(j).entryId === want[i].id) {
            at = j;
            break;
          }
        }
        if (at < 0)
          rows.insert(i, {
            entryId: want[i].id,
            rowName: String(want[i].name),
            rowDesc: AppSearch.describe(want[i]),
            rowIcon: AppSearch.iconFor(want[i])
          });
        else if (at !== i)
          rows.move(at, i, 1);
      }
    }

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Ignore

    // Same focus prime as Ui/PanelHost.qml: Hyprland focuses an OnDemand
    // surface when it first maps, but not when an already-mapped one goes
    // None -> OnDemand, and this surface stays mapped through its close
    // animation. Exclusive covers the second case; staying Exclusive is not an
    // option, because it would route every pointer event on every output here.
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
        // Layer-shell hands the surface focus, but Qt still needs an
        // active-focus target inside it before the input sees a key.
        Qt.callLater(function () {
          if (win.open)
            query.forceActiveFocus();
        });
      } else {
        focusPrime.stop();
        focusPrimed = false;
      }
    }

    onShowingChanged: {
      if (showing) {
        Bus.launcherScreen = win.screen ? win.screen.name : "";
      } else {
        // The close is off screen; the shape Behaviors are live again for
        // the next open. A held still unmaps with handover still raised,
        // which is what keeps its cut to the pill instant.
        win.handover = false;
        if (win.screen && Bus.launcherScreen === win.screen.name)
          Bus.launcherScreen = "";
      }
    }

    Connections {
      target: Bus

      function onLauncherToggled() {
        if (win.open)
          win.hide();
        else if (win.focused)
          win.show();
      }

      function onLauncherClosed() {
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

    Connections {
      target: AppSearch

      function onResultsChanged() {
        win.syncRows();
      }
    }

    ListModel {
      id: rows
    }

    Component.onCompleted: win.syncRows()

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

      implicitWidth: win.open ? Theme.launcherWidth : origin.held ? origin.heldWidth : origin.originWidth
      implicitHeight: win.open ? win.openHeight : origin.held ? origin.heldHeight : origin.originHeight
      surfaceRadius: win.open ? Theme.launcherRadius : origin.held ? origin.heldRadius : origin.originRadius

      Behavior on implicitWidth {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphLauncher
        }
      }

      Behavior on implicitHeight {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphLauncher
        }
      }

      Behavior on surfaceRadius {
        enabled: !origin.snapping && (!win.handover || origin.held)

        Morph {
          duration: origin.held ? origin.heldDuration : Theme.morphLauncher
        }
      }

      // The carried-over clock; see Ui/IslandClock.qml.
      IslandClock {
        anchors.fill: parent
        origin: origin
        shown: !win.open && !origin.held
      }

      // Everything the launcher draws, cross-faded against the clock on the
      // same short clock the island uses for its own contents. The rows inside
      // do not fade individually; the growing shape uncovers them.
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
          x: Theme.launcherGlyphLeft
          y: Theme.launcherSearchHeight / 2 - height / 2
          text: Icons.search
          color: Theme.muted
          font.family: Theme.iconFont
          font.pixelSize: Theme.launcherGlyphSize
        }

        TextInput {
          id: query

          x: Theme.launcherTextLeft
          y: Theme.launcherSearchHeight / 2 - height / 2
          width: Theme.launcherWidth - x - Theme.launcherInset
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherSearchSize
          selectByMouse: true
          selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
          clip: true

          onTextChanged: {
            AppSearch.query = text;
            list.currentIndex = 0;
          }

          cursorDelegate: Rectangle {
            width: 1.5
            radius: 0.75
            color: Theme.accent
          }

          Text {
            text: "Search…"
            color: Theme.muted
            font: query.font
            visible: query.text.length === 0
          }

          Keys.onPressed: function (event) {
            switch (event.key) {
            case Qt.Key_Escape:
              win.hide();
              break;
            case Qt.Key_Up:
            case Qt.Key_Backtab:
              if (list.currentIndex > 0)
                list.currentIndex--;
              break;
            case Qt.Key_Down:
            case Qt.Key_Tab:
              if (list.currentIndex < rows.count - 1)
                list.currentIndex++;
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

        Rectangle {
          x: Theme.launcherInset
          y: Theme.launcherSearchHeight
          width: Theme.launcherWidth - Theme.launcherInset * 2
          height: 1
          color: Theme.withAlpha(Theme.highlightMed, 0.6)
        }

        Text {
          x: Theme.launcherTextLeft
          y: Theme.launcherListTop + (Theme.launcherRowHeight - height) / 2
          text: "No matches"
          color: Theme.muted
          visible: rows.count === 0
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherNameSize
        }

        ListView {
          id: list

          x: Theme.launcherInset
          y: Theme.launcherListTop
          width: Theme.launcherWidth - Theme.launcherInset * 2
          height: win.listHeight
          model: rows
          spacing: Theme.launcherRowGap
          clip: true
          currentIndex: 0
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick

          // Keep the selection on screen once the list is longer than the
          // panel, without pinning it to a fixed row.
          highlightRangeMode: ListView.ApplyRange
          preferredHighlightBegin: 0
          preferredHighlightEnd: height
          highlightMoveDuration: Theme.animSlow
          highlightMoveVelocity: -1
          highlightResizeDuration: 0

          highlight: Item {
            Rectangle {
              anchors.fill: parent
              radius: Theme.launcherRowRadius
              color: Theme.withAlpha(Theme.text, 0.06)
            }

            // The one piece of colour in the panel, and the only thing that
            // says which row Enter would launch.
            Rectangle {
              y: (parent.height - height) / 2
              width: Theme.launcherMarkerWidth
              height: Theme.launcherMarkerHeight
              radius: width / 2
              color: Theme.accent
            }
          }

          delegate: LauncherRow {
            required property int index
            required property string rowName
            required property string rowDesc
            required property string rowIcon

            width: list.width
            height: Theme.launcherRowHeight
            name: rowName
            description: rowDesc
            iconSource: rowIcon

            onActivated: {
              list.currentIndex = index;
              win.activate();
            }
          }

          add: Transition {
            NumberAnimation {
              property: "opacity"
              from: 0
              to: 1
              duration: Theme.animFast
            }
          }

          remove: Transition {
            NumberAnimation {
              property: "opacity"
              to: 0
              duration: Theme.animFast
            }
          }

          // Survivors travel on the same curve as the shape they sit in, which
          // is why two of them can be seen crossing rather than shoving.
          displaced: Transition {
            NumberAnimation {
              properties: "y"
              duration: Theme.morphDuration
              easing.type: Easing.Bezier
              easing.bezierCurve: Theme.morphCurve
            }
            NumberAnimation {
              property: "opacity"
              to: 1
              duration: Theme.animFast
            }
          }
        }
      }
    }

    // The launcher is a keyboard surface. Every way of getting anywhere in it -
    // the query, the selection, the launch - is a key, so while it is up the
    // pointer is taken off the screen rather than left hovering over a list it
    // no longer drives.
    //
    // This sits over everything and accepts no buttons, so it changes nothing
    // but the cursor: a press falls straight through it to the dismiss area and
    // the rows underneath. Being the topmost item that carries a cursor at all
    // is the whole point, because that is what outranks the query's I-beam and
    // the rows' pointing hand without having to reach into either.
    //
    // Bound rather than switched off, so the pointer comes back on the frame
    // the launcher closes: an item that is merely disabled keeps the cursor it
    // last set until something else moves.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      cursorShape: win.open ? Qt.BlankCursor : Qt.ArrowCursor
    }
  }
}
