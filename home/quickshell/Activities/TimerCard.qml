import QtQuick
import qs.Commons
import qs.Services
import "../Commons/Duration.js" as Duration

// A timer's hover card (Penpot "Ariadne / Activity card / Timer"): its label and length, the
// time left big, when it ends, a track running down, and Pause / +1 min / Cancel.
Item {
  id: root

  required property int timerId

  readonly property var t: Timers.byId(timerId)
  readonly property real remainingMs: Timers.remaining(t)
  readonly property bool onHold: t !== null && t.paused
  readonly property color tint: onHold ? Theme.inkTertiary : Theme.accent

  implicitWidth: Theme.activityCardWidth
  implicitHeight: 198

  CardHeader {
    icon: IconPaths.timer
    tint: Theme.accent
    title: root.t && root.t.label !== "" ? root.t.label : "Timer"
    caption: root.t ? Duration.describe(root.t.total) + " timer" : ""
  }

  Text {
    x: Theme.activityCardPad
    y: 94 - height / 2
    text: Duration.clock(root.remainingMs)
    color: root.onHold ? Theme.inkSecondary : Theme.inkPrimary
    font.family: Theme.displayFont
    font.pixelSize: 44
    font.weight: Theme.weightSemi
    font.features: {
      "tnum": 1
    }
  }

  Text {
    x: root.width - Theme.activityCardPad - width
    y: 106 - height / 2
    text: root.onHold ? "Paused" : "Ends " + Timers.endsText(root.t)
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: 12
  }

  ProgressTrack {
    x: Theme.activityCardPad
    y: 130
    width: root.width - 2 * Theme.activityCardPad
    fraction: root.t ? root.remainingMs / root.t.total : 0
    tint: root.tint
  }

  Row {
    x: Theme.activityCardPad
    y: 152
    spacing: Theme.activityButtonGap

    ActivityButton {
      width: 112
      kind: "primary"
      icon: root.onHold ? IconPaths.play : IconPaths.pause
      text: root.onHold ? "Resume" : "Pause"
      onClicked: root.onHold ? Timers.resume(root.timerId) : Timers.pause(root.timerId)
    }

    ActivityButton {
      width: 96
      kind: "secondary"
      icon: IconPaths.plus
      text: "+1 min"
      onClicked: Timers.add(root.timerId, "1m")
    }

    ActivityButton {
      width: 84
      kind: "ghost"
      icon: IconPaths.x
      text: "Cancel"
      onClicked: Timers.cancel(root.timerId)
    }
  }
}
