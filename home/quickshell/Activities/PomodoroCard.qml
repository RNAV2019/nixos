import QtQuick
import qs.Commons
import qs.Services
import "../Commons/Duration.js" as Duration

// The Pomodoro's hover card (Penpot "Ariadne / Activity card / Pomodoro"): the phase and its
// round, the cycle as four dots, the time left, when the next phase starts, and Pause / Skip /
// Stop. Gold for focus, foam for a break.
Item {
  id: root

  readonly property bool inFocus: Pomodoro.focus
  readonly property color role: inFocus ? Theme.gold : Theme.foam
  readonly property bool onHold: Pomodoro.paused
  readonly property real remainingMs: Pomodoro.left

  implicitWidth: Theme.activityCardWidth
  implicitHeight: 198

  CardHeader {
    icon: root.inFocus ? IconPaths.timer : IconPaths.coffee
    tint: root.role
    title: Pomodoro.title(Pomodoro.phase)
    caption: Pomodoro.caption()
    reserve: Pomodoro.rounds * Theme.activityDotPitch
  }

  // Done is filled, the round under way a ring, the rest the track's colour.
  Repeater {
    model: Pomodoro.rounds

    Rectangle {
      required property int index

      readonly property bool done: index < Pomodoro.doneRounds
      readonly property bool current: root.inFocus && index === Pomodoro.round - 1

      x: root.width - Theme.activityCardPad - Theme.activityDotSize - (Pomodoro.rounds - 1 - index) * Theme.activityDotPitch
      y: 34 - Theme.activityDotSize / 2
      width: Theme.activityDotSize
      height: width
      radius: width / 2
      color: done ? root.role : current ? "transparent" : Theme.surfaceRaised
      border.width: current ? 1.5 : 0
      border.color: root.role
    }
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
    text: Pomodoro.nextText()
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: 12
  }

  ProgressTrack {
    x: Theme.activityCardPad
    y: 130
    width: root.width - 2 * Theme.activityCardPad
    fraction: Pomodoro.total > 0 ? root.remainingMs / Pomodoro.total : 0
    tint: root.onHold ? Theme.inkTertiary : root.role
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
      onClicked: root.onHold ? Pomodoro.resume() : Pomodoro.pause()
    }

    ActivityButton {
      width: 96
      kind: "secondary"
      icon: IconPaths.skipForward
      text: "Skip"
      onClicked: Pomodoro.skip()
    }

    ActivityButton {
      width: 84
      kind: "ghost"
      icon: IconPaths.square
      text: "Stop"
      onClicked: Pomodoro.stop()
    }
  }
}
