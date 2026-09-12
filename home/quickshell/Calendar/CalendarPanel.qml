import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The calendar: the island grown into a card. The grid is six rows of seven, always,
// so the panel keeps its height between a five-row month and a six-row one.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "calendar"
    openWidth: Theme.panelWidth(modelData, Theme.calWidth)
    openHeight: Theme.calHeight
    openRadius: Theme.calRadius

    // The first cell: the Monday on or before the first of the month. The (day + 6) % 7
    // shift is because JavaScript counts Sunday as zero.
    readonly property date gridStart: {
      var first = new Date(Calendar.anchor.getFullYear(), Calendar.anchor.getMonth(), 1);
      var shift = (first.getDay() + 6) % 7;
      return new Date(first.getFullYear(), first.getMonth(), 1 - shift);
    }

    function cellDate(i) {
      return new Date(win.gridStart.getFullYear(), win.gridStart.getMonth(), win.gridStart.getDate() + i);
    }

    readonly property var agenda: Calendar.eventsOn(Calendar.selected)

    onOpening: {
      Calendar.today();
    }

    onKeyPressed: function (event) {
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
          case Qt.Key_Up:
            Calendar.stepDay(-7);
            break;
          case Qt.Key_Down:
            Calendar.stepDay(7);
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

        Text {
          x: Theme.calInset
          y: Theme.calTitleTop
          text: Qt.formatDateTime(Calendar.anchor, "MMMM yyyy")
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.calTitleSize
          font.weight: Font.DemiBold
        }

        Rectangle {
          id: todayBtn

          x: prev.x - width - Theme.calNavGap * 2
          y: Theme.calNavTop + (Theme.calNavSize - height) / 2
          width: todayLabel.implicitWidth + 22
          height: Theme.calTodayBtnHeight
          radius: height / 2
          Accessible.role: Accessible.Button
          Accessible.name: "Today"
          Accessible.focusable: true
          Accessible.focused: todayHover.activeFocus
          Accessible.onPressAction: Calendar.today()
          color: Theme.withAlpha(Theme.highlightMed, todayHover.containsMouse ? 1 : 0.75)
          scale: todayHover.pressed ? 0.97 : 1

          Behavior on color {
            Tint {}
          }

          Behavior on scale {
            Morph { duration: Theme.morphState }
          }

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
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            onPressed: todayHover.forceActiveFocus()
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
          Accessible.role: Accessible.Button
          Accessible.name: "Previous month"
          Accessible.focusable: true
          Accessible.focused: prevHover.activeFocus
          Accessible.onPressAction: Calendar.step(-1)
          color: Theme.withAlpha(Theme.highlightLow, prevHover.containsMouse ? 1 : 0.9)
          scale: prevHover.pressed ? 0.95 : 1

          Behavior on color {
            Tint {}
          }

          Behavior on scale {
            Morph { duration: Theme.morphState }
          }

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
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            onPressed: prevHover.forceActiveFocus()
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
          Accessible.role: Accessible.Button
          Accessible.name: "Next month"
          Accessible.focusable: true
          Accessible.focused: nextHover.activeFocus
          Accessible.onPressAction: Calendar.step(1)
          color: Theme.withAlpha(Theme.highlightLow, nextHover.containsMouse ? 1 : 0.9)
          scale: nextHover.pressed ? 0.95 : 1

          Behavior on color {
            Tint {}
          }

          Behavior on scale {
            Morph { duration: Theme.morphState }
          }

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
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            onPressed: nextHover.forceActiveFocus()
            onClicked: Calendar.step(1)
          }
        }

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
            width: Theme.calColumnPitch
            height: Theme.calRowPitch

            // Today is where the selection starts, so a ring says "today, but you are
            // looking elsewhere".
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
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              y: (parent.height - height) / 2
              text: cell.day.getDate()
              color: cell.isSelected ? Theme.inkOnAccent : cell.inMonth ? Theme.inkPrimary : Theme.inkTertiary
              font.family: Theme.uiFont
              font.pixelSize: Theme.calDaySize
              font.weight: cell.isSelected || cell.isToday ? Font.DemiBold : Font.Normal
            }

            // One dot per day that has anything, in the colour of its first calendar.
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
               onClicked: Calendar.selectDay(cell.day)
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

        // Room for three rows; a fuller day says how many more rather than scrolling.
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

        // Covers every state the list is not in: empty, truncated, loading, or never set up.
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
