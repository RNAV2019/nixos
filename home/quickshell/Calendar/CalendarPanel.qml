import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The calendar: the island grown into a wide, low card. The month is on the left, always six rows
// of seven, and the chosen day's agenda on the right, so the size never varies with month or day.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "calendar"
    openWidth: Theme.panelWidth(modelData, Theme.calWidth)
    openHeight: Theme.calHeight
    openRadius: Theme.calRadius

    // First cell: the Monday on or before the 1st; the (day + 6) % 7 shift is for JS's Sunday=0.
    readonly property date gridStart: {
      var first = new Date(Calendar.anchor.getFullYear(), Calendar.anchor.getMonth(), 1);
      var shift = (first.getDay() + 6) % 7;
      return new Date(first.getFullYear(), first.getMonth(), 1 - shift);
    }

    function cellDate(i) {
      return new Date(win.gridStart.getFullYear(), win.gridStart.getMonth(), win.gridStart.getDate() + i);
    }

    readonly property var agenda: Calendar.eventsOn(Calendar.selected)

    // How far off the chosen day is, for the eyebrow over its name.
    readonly property string distance: {
      var now = new Date();
      var d = win.dayIndex - Math.floor(new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 86400000);
      if (d === 0)
        return "Today";
      if (d === 1)
        return "Tomorrow";
      if (d === -1)
        return "Yesterday";
      return d > 0 ? "In " + d + " days" : -d + " days ago";
    }

    // Each day opens at its first event, not wherever the last day was scrolled to.
    onAgendaChanged: {
      agendaView.openRow = -1;
      agendaView.wantRow = -1;
      agendaView.scrollToTop();
    }

    // How long something lasts, as an agenda row says it.
    function lasting(mins) {
      return mins < 60 ? mins + " min" : (mins % 60 === 0 ? (mins / 60) + " hr" : (mins / 60).toFixed(1) + " hr");
    }

    onOpening: {
      Calendar.today();
    }

    // A month or day change is a content swap inside one shape, so it takes the arrival a
    // surface's contents take out of another panel: a short fade, settling a few px along the
    // way time moved. The swap itself stays immediate, so held keys never queue behind it.
    readonly property int monthIndex: Calendar.anchor.getFullYear() * 12 + Calendar.anchor.getMonth()
    readonly property int dayIndex: Math.floor(new Date(Calendar.selected.getFullYear(), Calendar.selected.getMonth(), Calendar.selected.getDate()).getTime() / 86400000)
    property int lastMonth: -1
    property int lastDay: -1

    Component.onCompleted: {
      lastMonth = monthIndex;
      lastDay = dayIndex;
    }

    function arrive(anim, delta) {
      if (delta === 0 || !win.open || Theme.reduceMotion)
        return;
      anim.travel = (delta > 0 ? 1 : -1) * Theme.morphEnterTravel;
      anim.restart();
    }

    onMonthIndexChanged: {
      var delta = monthIndex - lastMonth;
      lastMonth = monthIndex;
      arrive(monthArrival, delta);
    }

    onDayIndexChanged: {
      var delta = dayIndex - lastDay;
      lastDay = dayIndex;
      arrive(dayArrival, delta);
    }

    Arrival {
      id: monthArrival

      layer: monthLayer
    }

    Arrival {
      id: dayArrival

      layer: dayLayer
    }

    Panel {
      id: panel

      surface: win
      title: Qt.formatDateTime(Calendar.anchor, "MMMM yyyy")
      titleWeight: Theme.weightSemi
      headerTop: Theme.calHeaderTop
      takesMove: true
      header.titleOpacity: monthLayer.opacity
      header.titleShift: monthLayer.shift
      // The header is the month's: it ends where the left pane does.
      header.width: Theme.calSplit

      // The arrows walk the grid: left and right a day, up and down a week, and the month follows
      // the day across its edge. Page Up and Page Down turn the month.
      onMoved: function (dx, dy) {
        Calendar.stepDay(dx + 7 * dy);
      }

      onKeyPressed: function (event) {
        switch (event.key) {
        case Qt.Key_T:
        case Qt.Key_Home:
          Calendar.today();
          break;
        case Qt.Key_R:
          Calendar.refresh();
          break;
        case Qt.Key_PageUp:
          Calendar.step(-1);
          break;
        case Qt.Key_PageDown:
          Calendar.step(1);
          break;
        default:
          return;
        }
        event.accepted = true;
      }

      headerActions: [
        Button {
          size: Button.Compact
          text: "Today"
          onClicked: Calendar.today()
        },
        Button {
          kind: Button.Disc
          size: Button.Compact
          icon: Icons.chevronLeft
          accessibleName: "Previous month"
          onClicked: Calendar.step(-1)
        },
        Button {
          kind: Button.Disc
          size: Button.Compact
          icon: Icons.chevronRight
          accessibleName: "Next month"
          onClicked: Calendar.step(1)
        }
      ]

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

      // The month's title and grid move as one; the nav and weekday header stay put.
      ArrivalLayer {
        id: monthLayer

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
            y: Theme.calGridTop + Math.floor(index / 7) * Theme.calRowPitch
            width: Theme.calColumnPitch
            height: Theme.calRowPitch

            // Today is where the selection starts, so a ring says "today, but looking elsewhere".
            Rectangle {
              x: (parent.width - Theme.calTodayMarker) / 2
              y: (parent.height - Theme.calTodayMarker) / 2
              width: Theme.calTodayMarker
              height: Theme.calTodayMarker
              radius: width / 2
              visible: cell.isSelected || cell.isToday || pointer.containsMouse
              // Under the pointer a day lifts like any control, so the grid reads as pressable.
              color: cell.isSelected ? Theme.accent : pointer.containsMouse ? Theme.lift(Theme.liftControlHover) : "transparent"
              border.width: cell.isSelected || !cell.isToday ? 0 : 1
              border.color: Theme.withAlpha(Theme.accent, 0.55)

              Behavior on color {
                Tint {}
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              y: (parent.height - height) / 2
              text: cell.day.getDate()
              color: cell.isSelected ? Theme.inkOnAccent : cell.inMonth ? Theme.inkPrimary : Theme.inkTertiary
              font.family: Theme.uiFont
              font.pixelSize: Theme.calDaySize
              font.weight: cell.isSelected || cell.isToday ? Font.DemiBold : Font.Normal

              Behavior on color {
                Tint {}
              }
            }

            // One dot per day with events, in its first calendar's colour. It hangs under the
            // number but stays inside the marker; on the selected day it takes the ink on the fill.
            Rectangle {
              x: (parent.width - width) / 2
              y: parent.height / 2 + Theme.calDotDrop - height / 2
              width: Theme.calDotSize
              height: width
              radius: width / 2
              visible: Calendar.hasEvents(cell.day)
              color: {
                if (cell.isSelected)
                  return Theme.inkOnAccent;
                var day = Calendar.eventsOn(cell.day);
                return day.length > 0 ? Calendar.colourFor(day[0].calendar) : Theme.accent;
              }
            }

            MouseArea {
              id: pointer

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Calendar.selectDay(cell.day)
            }
          }
        }
      }

      Divider {
        x: Theme.calSplit
        y: Theme.calRuleInset
        vertical: true
        implicitHeight: panel.height - Theme.calRuleInset * 2
      }

      // The selected day's name, agenda and footnote arrive together.
      ArrivalLayer {
        id: dayLayer

        readonly property real paneWidth: panel.width - Theme.calAgendaLeft - Theme.calInset

        Text {
          x: Theme.calAgendaLeft
          y: Theme.calEyebrowTop
          width: dayLayer.paneWidth
          text: win.distance
          color: win.distance === "Today" ? Theme.accent : Theme.inkTertiary
          font.family: Theme.uiFont
          font.pixelSize: Theme.calEyebrowSize
          font.weight: Theme.weightMedium
          elide: Text.ElideRight
        }

        Text {
          x: Theme.calAgendaLeft
          y: Theme.calHeadingTop
          width: dayLayer.paneWidth
          text: Qt.formatDateTime(Calendar.selected, "dddd d MMMM")
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.calHeadingSize
          font.weight: Theme.weightSemi
          elide: Text.ElideRight
        }

        // Room for six rows; a fuller day scrolls one row per wheel notch, keeping rows aligned.
        ScrollView {
          id: agendaView

          x: Theme.calAgendaLeft
          y: Theme.calAgendaTop
          width: dayLayer.paneWidth
          height: Theme.calAgendaBlock
          wheelStep: Theme.calAgendaHeight + Theme.calAgendaGap

          // The row the pointer has open (-1: none). The first waits a moment, the next a shorter
          // one, and none shuts in the gap between two.
          property int openRow: -1
          property int wantRow: -1

          function hover(index, on) {
            if (on) {
              shut.stop();
              wantRow = index;
              if (openRow === index) {
                open.stop();
                return;
              }
              open.interval = openRow >= 0 ? Theme.calAgendaHoverSwap : Theme.calAgendaHoverDelay;
              open.restart();
            } else if (wantRow === index) {
              wantRow = -1;
              open.stop();
              shut.restart();
            }
          }

          Timer {
            id: open

            interval: Theme.calAgendaHoverDelay
            onTriggered: agendaView.openRow = agendaView.wantRow
          }

          Timer {
            id: shut

            interval: Theme.calAgendaHoverGrace
            onTriggered: agendaView.openRow = -1
          }

          Column {
            width: agendaView.width
            spacing: Theme.calAgendaGap

            Repeater {
              model: win.agenda.length

              Rectangle {
                id: row

                required property int index

                readonly property var event: win.agenda[index]
                readonly property bool expanded: agendaView.openRow === index
                // One line of the title, which the first line of every row is centred on, open or shut.
                readonly property real lineTop: (Theme.calAgendaHeight - titleLine.height) / 2
                readonly property real openHeight: details.y + details.implicitHeight + Theme.calAgendaDetailPad

                // When it runs, and for how long.
                readonly property string span: {
                  if (row.event.allDay)
                    return "All day";
                  var from = Qt.formatDateTime(row.event.start, "HH:mm");
                  var mins = Math.round((row.event.end - row.event.start) / 60000);
                  if (mins <= 0)
                    return from;
                  return from + " – " + Qt.formatDateTime(row.event.end, "HH:mm") + "  ·  " + win.lasting(mins);
                }

                width: agendaView.width
                height: expanded ? openHeight : Theme.calAgendaHeight
                radius: Theme.calAgendaRadius
                color: Theme.lift(expanded || pointer.hovered ? Theme.liftHover : Theme.liftTile)
                clip: true

                Behavior on height {
                  Morph {
                    duration: Theme.morphState
                  }
                }

                Behavior on color {
                  Tint {}
                }

                HoverHandler {
                  id: pointer

                  onHoveredChanged: agendaView.hover(row.index, hovered)
                }

                // Opened low in the list, it is brought wholly into view once it has its height.
                onExpandedChanged: if (expanded)
                  reveal.restart()

                Timer {
                  id: reveal

                  interval: Theme.morphState + 20
                  onTriggered: {
                    if (!row.expanded)
                      return;
                    var over = row.y + row.height - (agendaView.contentY + agendaView.height);
                    if (over > 0.5)
                      agendaView.feed(over, false);
                  }
                }

                Rectangle {
                  x: Theme.calSpineLeft
                  y: (Theme.calAgendaHeight - height) / 2
                  width: Theme.calSpineWidth
                  height: Theme.calSpineHeight
                  radius: width / 2
                  color: Calendar.colourFor(row.event.calendar)
                }

                Text {
                  x: Theme.calTimeLeft
                  y: (Theme.calAgendaHeight - height) / 2
                  // An all-day event has no time: its title starts here and "All day" goes to the far end.
                  visible: !row.event.allDay
                  text: Qt.formatDateTime(row.event.start, "HH:mm")
                  color: Theme.subtle
                  font.family: Theme.monoFont
                  font.pixelSize: Theme.calTimeSize
                }

                // Measures one line, so the title's first line sits where it does shut.
                Text {
                  id: titleLine

                  visible: false
                  text: "X"
                  font: title.font
                }

                Text {
                  id: title

                  x: row.event.allDay ? Theme.calTimeLeft : Theme.calTitleLeft
                  y: row.lineTop
                  // Shut, it stops short of the far end's line; open, that line has gone under it and
                  // the title has the row, on two lines if it needs them.
                  width: Math.max(0, (row.expanded ? row.width - Theme.calSpineLeft : meta.x - 12) - x)
                  text: row.event.title
                  color: Theme.text
                  font.family: Theme.uiFont
                  font.pixelSize: Theme.calEventTitleSize
                  elide: Text.ElideRight
                  wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                  maximumLineCount: row.expanded ? 2 : 1
                }

                Text {
                  id: meta

                  x: parent.width - width - Theme.calSpineLeft
                  y: (Theme.calAgendaHeight - height) / 2
                  width: Math.min(implicitWidth, Theme.calMetaMax)
                  text: {
                    if (row.event.location !== "")
                      return row.event.location;
                    if (row.event.allDay)
                      return "All day";
                    var mins = Math.round((row.event.end - row.event.start) / 60000);
                    return mins <= 0 ? "" : win.lasting(mins);
                  }
                  color: Theme.muted
                  font.family: Theme.uiFont
                  font.pixelSize: Theme.calMetaSize
                  elide: Text.ElideRight
                  // Said in full underneath while the row is open.
                  opacity: row.expanded ? 0 : 1
                  visible: opacity > 0

                  Behavior on opacity {
                    ContentFade {}
                  }
                }

                Column {
                  id: details

                  x: title.x
                  y: title.y + title.height + Theme.calAgendaDetailGap + 1
                  width: row.width - x - Theme.calSpineLeft
                  spacing: Theme.calAgendaDetailGap
                  opacity: row.expanded ? 1 : 0
                  visible: opacity > 0

                  Behavior on opacity {
                    ContentFade {}
                  }

                  Repeater {
                    model: [row.span, row.event.location, row.event.calendar]

                    Text {
                      required property string modelData
                      required property int index

                      width: details.width
                      visible: modelData !== ""
                      text: modelData
                      color: index === 0 ? Theme.subtle : Theme.muted
                      font.family: Theme.uiFont
                      font.pixelSize: Theme.calAgendaDetailSize
                      elide: Text.ElideRight
                      wrapMode: index === 1 ? Text.Wrap : Text.NoWrap
                      maximumLineCount: index === 1 ? 2 : 1
                    }
                  }
                }
              }
            }
          }
        }

        // Covers the states the list is not in: empty, truncated, loading, or never set up. With
        // rows it is a footnote under the reserved block; with none it is centred, reading as empty.
        Text {
          readonly property bool alone: win.agenda.length === 0

          x: Theme.calAgendaLeft
          y: alone ? Theme.calAgendaTop + (Theme.calAgendaBlock - height) / 2 : Theme.calAgendaTop + Theme.calAgendaBlock + Theme.calAgendaGap + 2
          width: dayLayer.paneWidth
          horizontalAlignment: alone ? Text.AlignHCenter : Text.AlignLeft
          wrapMode: alone ? Text.Wrap : Text.NoWrap
          maximumLineCount: 3
          elide: Text.ElideRight
          text: {
            if (Calendar.error !== "")
              return Calendar.error;
            if (Calendar.loading && win.agenda.length === 0)
              return "Loading…";
            if (win.agenda.length === 0)
              return "Nothing on";
            // Only rows still below the view count, so it clears once scrolled to the end.
            var scrolled = Math.floor(agendaView.contentY / (Theme.calAgendaHeight + Theme.calAgendaGap));
            var more = win.agenda.length - Theme.calAgendaMax - scrolled;
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
