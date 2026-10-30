import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The glance row under the clock: the battery and the next event today, two flat chips.
// It shows nothing the desk behind the lock would not already tell a passer-by: no
// notification text, only a calendar title the design calls for.
Item {
  id: root

  // The lock canvas's unit scale (its height / 1080), so the board's sizes carry over.
  property real ui: 1
  // Lets the IPC preview rehearse a battery on a machine that has none.
  property bool forceBattery: false
  property real forceLevel: 0.82
  property bool forceCharging: false

  function u(v) {
    return Math.round(v * root.ui);
  }

  readonly property bool batteryPresent: forceBattery || Battery.present
  readonly property real level: forceBattery ? forceLevel : Battery.level
  readonly property bool charging: forceBattery ? forceCharging : Battery.charging
  readonly property bool low: batteryPresent && !charging && level <= Battery.lowLevel

  // Time passes under a long lock; the event that has ended must drop off.
  readonly property date now: clock.date

  // The first timed event today that has not finished: all-day events carry no time to show.
  readonly property var event: {
    var list = Calendar.eventsOn(root.now);
    for (var i = 0; i < list.length; i++) {
      if (!list[i].allDay && list[i].end > root.now)
        return list[i];
    }
    return null;
  }

  readonly property bool eventStarted: event !== null && event.start <= now
  readonly property string eventTime: {
    if (event === null)
      return "";
    if (eventStarted)
      return "until " + Qt.formatTime(event.end, "HH:mm");
    return Qt.formatTime(event.start, "HH:mm");
  }

  readonly property bool hasChips: batteryPresent || event !== null

  width: u(Theme.lockPillWidth)
  height: u(Theme.lockGlanceHeight)
  visible: hasChips

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  // The calendar holds one month at a time; bring it to today's before the lock reads it.
  Component.onCompleted: Calendar.today()

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    height: parent.height
    spacing: root.u(Theme.lockGlanceGap)

    Rectangle {
      id: batteryChip

      visible: root.batteryPresent
      width: Math.max(root.u(Theme.lockBatteryChipWidth), batteryRow.implicitWidth + 2 * root.u(Theme.lockGlanceInset))
      height: parent.height
      radius: height / 2
      color: Theme.surface
      border.width: Math.max(1, Math.round(root.ui))
      border.color: Theme.surfaceOutline

      Row {
        id: batteryRow

        anchors.centerIn: parent
        spacing: root.u(6)

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: root.u(Theme.lockGlanceGlyph)
          strokeWidth: 1.75 * root.ui
          color: root.low ? Theme.love : root.charging ? Theme.accent : Theme.inkSecondary
          path: root.charging ? IconPaths.batteryCharging : IconPaths.battery
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Math.round(root.level * 100) + "%"
          color: root.low ? Theme.love : Theme.inkPrimary
          font.family: Theme.uiFont
          font.weight: Theme.weightSemi
          font.pixelSize: root.u(Theme.lockGlanceTextSize)
          renderType: Text.QtRendering
        }
      }
    }

    Rectangle {
      id: eventChip

      visible: root.event !== null
      width: root.u(Theme.lockEventChipWidth)
      height: parent.height
      radius: height / 2
      color: Theme.surface
      border.width: Math.max(1, Math.round(root.ui))
      border.color: Theme.surfaceOutline

      Rectangle {
        id: spine

        x: root.u(Theme.lockGlanceInset)
        anchors.verticalCenter: parent.verticalCenter
        width: root.u(Theme.lockEventSpineWidth)
        height: root.u(Theme.lockEventSpineHeight)
        radius: width / 2
        color: root.event ? Calendar.colourFor(root.event.calendar) : "transparent"
      }

      Text {
        id: eventTime

        anchors.right: parent.right
        anchors.rightMargin: root.u(Theme.lockGlanceInset)
        anchors.verticalCenter: parent.verticalCenter
        text: root.eventTime
        color: Theme.inkTertiary
        font.family: Theme.uiFont
        font.weight: Theme.weightRegular
        font.pixelSize: root.u(Theme.lockGlanceTimeSize)
        renderType: Text.QtRendering
      }

      Text {
        x: root.u(Theme.lockEventTextLeft)
        anchors.verticalCenter: parent.verticalCenter
        width: eventTime.x - x - root.u(8)
        elide: Text.ElideRight
        text: root.event ? root.event.title : ""
        color: Theme.inkPrimary
        font.family: Theme.uiFont
        font.weight: Theme.weightMedium
        font.pixelSize: root.u(Theme.lockGlanceTextSize)
        renderType: Text.QtRendering
      }
    }
  }
}
