import QtQuick
import qs.Commons
import qs.Ui

// The next event's hover card (Penpot "Ariadne / Activity card / Event"): its title and time
// range, how long until it starts, where it is, and Open calendar, with Join beside it when the
// event carries a Meet, Teams, Zoom or Webex link.
Item {
  id: root

  // Activities/EventSource.qml, which knows the event and what the buttons do.
  required property var source

  readonly property var e: source.seen
  readonly property var link: source.linkOf(e)
  readonly property int minutes: source.minutesTo(source.current)
  readonly property bool starting: source.started(source.current)

  readonly property string countdown: {
    if (!root.starting)
      return "in " + root.minutes + " min";
    var ago = Math.floor((source.now - e.start.getTime()) / 60000);
    return ago < 1 ? "now" : "started " + ago + " min ago";
  }

  implicitWidth: Theme.activityCardWidth
  implicitHeight: 146

  CardHeader {
    icon: IconPaths.calendarClock
    tint: Theme.gold
    title: root.e ? root.e.title : ""
    caption: root.source.range(root.e)
    reserve: countdownText.width + 12
  }

  Text {
    id: countdownText

    x: root.width - Theme.activityCardPad - width
    y: 34 - height / 2
    text: root.countdown
    color: Theme.gold
    font.family: Theme.uiFont
    font.pixelSize: 12
    font.weight: Theme.weightSemi
  }

  StrokeIcon {
    x: Theme.activityCardPad
    y: 78 - size / 2
    visible: location.visible
    size: 13
    strokeWidth: 1.75
    path: IconPaths.mapPin
    color: Theme.inkTertiary
  }

  Text {
    id: location

    x: 36
    y: 78 - height / 2
    width: root.width - x - Theme.activityCardPad
    visible: root.e !== null && root.e.location !== ""
    elide: Text.ElideRight
    text: root.e ? root.e.location : ""
    textFormat: Text.PlainText
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: 12
  }

  // Primary on the right edge, the quieter button to its left.
  Row {
    x: root.width - Theme.activityCardPad - width
    y: 100
    spacing: Theme.activityButtonGap
    layoutDirection: Qt.RightToLeft

    ActivityButton {
      width: 84
      visible: root.link !== null
      kind: "primary"
      icon: IconPaths.camera
      text: "Join"
      onClicked: root.source.join(root.e)
    }

    ActivityButton {
      width: 116
      kind: "secondary"
      text: "Open calendar"
      onClicked: root.source.openCalendar(root.e)
    }
  }
}
