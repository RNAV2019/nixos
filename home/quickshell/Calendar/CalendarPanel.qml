import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The calendar: the island grown into a card. The grid is always six rows of seven, and the
// agenda always reserves Theme.calAgendaMax rows, so height never varies with month or day.
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

    // Each day opens at its first event, not wherever the last day was scrolled to.
    onAgendaChanged: agendaView.scrollToTop()

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

      // Left and right turn the month, up and down the week.
      onMoved: function (dx, dy) {
        if (dx !== 0)
          Calendar.step(dx);
        else
          Calendar.stepDay(7 * dy);
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
        default:
          return;
        }
        event.accepted = true;
      }

      headerActions: [
        HeaderButton {
          kind: HeaderButton.Label
          label: "Today"
          onClicked: Calendar.today()
        },
        HeaderButton {
          kind: HeaderButton.Previous
          accessibleName: "Previous month"
          onClicked: Calendar.step(-1)
        },
        HeaderButton {
          kind: HeaderButton.Next
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
              visible: cell.isSelected || cell.isToday
              color: cell.isSelected ? Theme.accent : "transparent"
              border.width: cell.isSelected ? 0 : 1
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
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Calendar.selectDay(cell.day)
            }
          }
        }
      }

      Divider {
        x: Theme.calInset
        y: Theme.calDividerTop
        width: panel.width - Theme.calInset * 2
      }

      // The selected day's heading, agenda and footnote arrive together.
      ArrivalLayer {
        id: dayLayer

        SectionLabel {
          x: Theme.calInset
          y: Theme.calSectionTop
          width: panel.width - Theme.calInset * 2
          verticalAlignment: Qt.AlignTop
          title: Qt.formatDateTime(Calendar.selected, "dddd, d MMMM")
        }

        // Room for three rows; a fuller day scrolls one row per wheel notch, keeping rows aligned.
        ScrollView {
          id: agendaView

          x: Theme.calInset
          y: Theme.calAgendaTop
          width: panel.width - Theme.calInset * 2
          height: Theme.calAgendaBlock
          wheelStep: Theme.calAgendaHeight + Theme.calAgendaGap

          Column {
            width: agendaView.width
            spacing: Theme.calAgendaGap

            Repeater {
              model: win.agenda.length

              Rectangle {
                id: row

                required property int index

                readonly property var event: win.agenda[index]

                width: agendaView.width
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
          }
        }

        // Covers the states the list is not in: empty, truncated, loading, or never set up. With
        // rows it is a footnote under the reserved block; with none it is centred, reading as empty.
        Text {
          readonly property bool alone: win.agenda.length === 0

          x: Theme.calInset
          y: alone ? Theme.calAgendaTop + (Theme.calAgendaBlock - height) / 2 : Theme.calAgendaTop + Theme.calAgendaBlock + Theme.calAgendaGap * 2
          width: panel.width - Theme.calInset * 2
          horizontalAlignment: alone ? Text.AlignHCenter : Text.AlignLeft
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

  component Arrival: ParallelAnimation {
    id: arrival

    property Item layer
    property real travel: 0

    NumberAnimation {
      target: arrival.layer
      property: "opacity"
      from: 0
      to: 1
      duration: Theme.duration(Theme.morphEnter)
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: arrival.layer
      property: "shift"
      from: arrival.travel
      to: 0
      duration: Theme.duration(Theme.morphEnter)
      easing.type: Easing.OutCubic
    }
  }

  // A layer the arrival moves, without disturbing its children's own coordinates.
  component ArrivalLayer: Item {
    id: layer

    property real shift: 0

    anchors.fill: parent
    transform: Translate {
      x: layer.shift
    }
  }
}
