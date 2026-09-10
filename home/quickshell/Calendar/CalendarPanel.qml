import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The calendar. Board 14, and the island's seventh shape.
//
// Same plan as every other surface on this layer: it starts at the pill's own
// size, radius and centre line and grows in its place, and the bar stands its
// island down while it is up. It is opened by clicking the clock, which is the
// one thing on the pill a calendar could sensibly hang off.
//
// The grid is six rows of seven, always, so the panel does not change height
// between a month that needs five rows and one that needs six. Days from the
// neighbouring months fill the ends and are drawn dimmed; they are still real
// days and still take a click.
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

    // The first cell of the grid: the Monday on or before the first of the
    // month. Weeks start on Monday, as the board draws them, which is why the
    // shift is (day + 6) % 7 rather than the day itself - JavaScript counts
    // Sunday as zero.
    readonly property date gridStart: {
      var first = new Date(Calendar.anchor.getFullYear(), Calendar.anchor.getMonth(), 1);
      var shift = (first.getDay() + 6) % 7;
      return new Date(first.getFullYear(), first.getMonth(), 1 - shift);
    }

    function cellDate(i) {
      return new Date(win.gridStart.getFullYear(), win.gridStart.getMonth(), win.gridStart.getDate() + i);
    }

    readonly property var agenda: Calendar.eventsOn(Calendar.selected)

    function show() {
      Calendar.today();
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it.
      handover = false;
      origin.claim(Theme.calWidth, Theme.calHeight, Theme.calRadius, Theme.morphWallpaper);
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

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calendar"

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
        Bus.calendarScreen = win.screen ? win.screen.name : "";
      } else {
        // The close is off screen; the shape Behaviors are live again for
        // the next open. A held still unmaps with handover still raised,
        // which is what keeps its cut to the pill instant.
        win.handover = false;
        if (win.screen && Bus.calendarScreen === win.screen.name)
          Bus.calendarScreen = "";
      }
    }

    Connections {
      target: Bus

      function onCalendarToggled() {
        if (win.open)
          win.hide();
        else if (win.focused)
          win.show();
      }

      function onCalendarClosed() {
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

      implicitWidth: win.open ? Theme.calWidth : origin.held ? origin.heldWidth : origin.originWidth
      implicitHeight: win.open ? Theme.calHeight : origin.held ? origin.heldHeight : origin.originHeight
      surfaceRadius: win.open ? Theme.calRadius : origin.held ? origin.heldRadius : origin.originRadius

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
            Calendar.step(-1);
            break;
          case Qt.Key_Right:
          case Qt.Key_L:
            Calendar.step(1);
            break;
          case Qt.Key_T:
          case Qt.Key_Home:
            Calendar.today();
            break;
          case Qt.Key_R:
            Calendar.refresh();
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

        Text {
          x: Theme.calInset
          y: Theme.calTitleTop
          text: Qt.formatDateTime(Calendar.anchor, "MMMM yyyy")
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.calTitleSize
          font.weight: Font.DemiBold
        }

        // Today, then the two arrows, laid out from the right inset back.
        Rectangle {
          id: todayBtn

          x: prev.x - width - Theme.calNavGap * 2
          y: Theme.calNavTop + (Theme.calNavSize - height) / 2
          width: todayLabel.implicitWidth + 22
          height: Theme.calTodayBtnHeight
          radius: height / 2
          color: Theme.withAlpha(Theme.highlightMed, todayHover.containsMouse ? 1 : 0.75)

          Text {
            id: todayLabel

            anchors.centerIn: parent
            text: "Today"
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: Theme.calTodayBtnSize
            font.weight: Font.Medium
          }

          MouseArea {
            id: todayHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Calendar.today()
          }
        }

        Rectangle {
          id: prev

          x: next.x - width - Theme.calNavGap
          y: Theme.calNavTop
          width: Theme.calNavSize
          height: width
          radius: width / 2
          color: Theme.withAlpha(Theme.highlightLow, prevHover.containsMouse ? 1 : 0.9)

          Text {
            anchors.centerIn: parent
            text: Icons.chevronLeft
            color: Theme.subtle
            font.family: Theme.iconFont
            font.pixelSize: Theme.calNavGlyphSize
          }

          MouseArea {
            id: prevHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Calendar.step(-1)
          }
        }

        Rectangle {
          id: next

          x: Theme.calWidth - Theme.calInset - width + 6
          y: Theme.calNavTop
          width: Theme.calNavSize
          height: width
          radius: width / 2
          color: Theme.withAlpha(Theme.highlightLow, nextHover.containsMouse ? 1 : 0.9)

          Text {
            anchors.centerIn: parent
            text: Icons.chevronRight
            color: Theme.subtle
            font.family: Theme.iconFont
            font.pixelSize: Theme.calNavGlyphSize
          }

          MouseArea {
            id: nextHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Calendar.step(1)
          }
        }

        // Weekday headings. Monday first, as the board draws them.
        Repeater {
          model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

          Text {
            required property int index
            required property string modelData

            x: Theme.calColumnFirst + index * Theme.calColumnPitch - width / 2
            y: Theme.calWeekdayTop
            text: modelData
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: Theme.calWeekdaySize
          }
        }

        // Six rows of seven, always, so the panel does not change height
        // between a five-row month and a six-row one.
        Repeater {
          model: 42

          Item {
            id: cell

            required property int index

            readonly property date day: win.cellDate(index)
            readonly property bool inMonth: day.getMonth() === Calendar.anchor.getMonth()
            readonly property bool isToday: Calendar.sameDay(day, new Date())
            readonly property bool isSelected: Calendar.sameDay(day, Calendar.selected)

            x: Theme.calColumnFirst + (index % 7) * Theme.calColumnPitch - width / 2
            y: Theme.calGridTop + Math.floor(index / 7) * Theme.calRowPitch - 8
            width: Theme.calTodayMarker
            height: Theme.calTodayMarker

            // The marker is the selection, and today is the selection's
            // starting place rather than a mark of its own. A ring says
            // "today, but you are looking elsewhere".
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              visible: cell.isSelected || cell.isToday
              color: cell.isSelected ? Theme.accent : "transparent"
              border.width: cell.isSelected ? 0 : 1
              border.color: Theme.withAlpha(Theme.accent, 0.55)
            }

            Text {
              anchors.centerIn: parent
              text: cell.day.getDate()
              color: cell.isSelected ? Theme.base : cell.inMonth ? Theme.text : Theme.muted
              font.family: Theme.uiFont
              font.pixelSize: Theme.calDaySize
              font.weight: cell.isSelected || cell.isToday ? Font.DemiBold : Font.Normal
            }

            // One dot per day that has anything, in the colour of the first
            // calendar that day draws from. A count of dots would turn the
            // grid into a chart; the agenda below is where the detail lives.
            Rectangle {
              x: (parent.width - width) / 2
              y: parent.height / 2 + Theme.calDotDrop - height / 2
              width: Theme.calDotSize
              height: width
              radius: width / 2
              visible: Calendar.hasEvents(cell.day)
              color: {
                var day = Calendar.eventsOn(cell.day);
                return day.length > 0 ? Calendar.colourFor(day[0].calendar) : Theme.accent;
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Calendar.selected = cell.day
            }
          }
        }

        Rectangle {
          x: Theme.calInset
          y: Theme.calDividerTop
          width: Theme.calWidth - Theme.calInset * 2
          height: 1
          color: Theme.withAlpha(Theme.highlightMed, 0.6)
        }

        Text {
          x: Theme.calInset
          y: Theme.calSectionTop
          text: Qt.formatDateTime(Calendar.selected, "dddd, d MMMM")
          color: Theme.muted
          font.family: Theme.uiFont
          font.pixelSize: Theme.calSectionSize
        }

        // What the day holds. The panel has room for three rows; a fuller day
        // says how many more there are rather than scrolling, because this is
        // a glance surface and scrolling is what the real calendar is for.
        Repeater {
          model: Math.min(win.agenda.length, Theme.calAgendaMax)

          Rectangle {
            id: row

            required property int index

            readonly property var event: win.agenda[index]

            x: Theme.calAgendaInset
            y: Theme.calAgendaTop + index * (Theme.calAgendaHeight + Theme.calAgendaGap)
            width: Theme.calWidth - Theme.calAgendaInset * 2
            height: Theme.calAgendaHeight
            radius: Theme.calAgendaRadius
            color: Theme.withAlpha(Theme.highlightLow, 0.9)

            Rectangle {
              x: Theme.calSpineLeft
              y: (parent.height - height) / 2
              width: Theme.calSpineWidth
              height: Theme.calSpineHeight
              radius: width / 2
              color: Calendar.colourFor(row.event.calendar)
            }

            Text {
              x: Theme.calTimeLeft
              y: (parent.height - height) / 2
              text: row.event.allDay ? "all day" : Qt.formatDateTime(row.event.start, "HH:mm")
              color: Theme.subtle
              font.family: Theme.monoFont
              font.pixelSize: Theme.calTimeSize
            }

            Text {
              x: Theme.calTitleLeft
              y: (parent.height - height) / 2
              width: Math.max(0, meta.x - x - 12)
              text: row.event.title
              color: Theme.text
              font.family: Theme.uiFont
              font.pixelSize: Theme.calEventTitleSize
              elide: Text.ElideRight
            }

            // The location if there is one, otherwise how long it runs. Both
            // answer "and what does that mean for my afternoon".
            Text {
              id: meta

              x: parent.width - width - Theme.calSpineLeft
              y: (parent.height - height) / 2
              text: {
                if (row.event.location !== "")
                  return row.event.location;
                if (row.event.allDay)
                  return "";
                var mins = Math.round((row.event.end - row.event.start) / 60000);
                if (mins <= 0)
                  return "";
                return mins < 60 ? mins + " min" : (mins % 60 === 0 ? (mins / 60) + " hr" : (mins / 60).toFixed(1) + " hr");
              }
              color: Theme.muted
              font.family: Theme.uiFont
              font.pixelSize: Theme.calMetaSize
              elide: Text.ElideRight
            }
          }
        }

        // The one line that covers every state the list is not in: nothing on,
        // more than fits, still loading, or the calendar never set up.
        Text {
          x: Theme.calInset
          y: Theme.calAgendaTop + Math.min(win.agenda.length, Theme.calAgendaMax) * (Theme.calAgendaHeight + Theme.calAgendaGap) + 4
          text: {
            if (Calendar.error !== "")
              return Calendar.error;
            if (Calendar.loading && win.agenda.length === 0)
              return "Loading…";
            if (win.agenda.length === 0)
              return "Nothing on";
            var more = win.agenda.length - Theme.calAgendaMax;
            return more > 0 ? "+ " + more + " more" : "";
          }
          color: Calendar.error !== "" ? Theme.urgent : Theme.muted
          font.family: Theme.uiFont
          font.pixelSize: Theme.calMetaSize
        }
      }
    }
  }
}
