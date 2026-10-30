import QtQuick
import qs.Commons
import qs.Services
import "../Commons/Duration.js" as Duration

// The Pomodoro (Services/Pomodoro.qml) as an activity: gold ring and a timer glyph while
// focusing, foam and a cup for either break, the ring running down the phase.
Activity {
  id: source

  readonly property color role: Pomodoro.focus ? Theme.gold : Theme.foam

  kind: "pomodoro"
  key: "pomodoro"
  active: Pomodoro.running
  since: Pomodoro.since

  icon: Pomodoro.focus ? IconPaths.timer : IconPaths.coffee
  ring: Pomodoro.total > 0 ? Pomodoro.left / Pomodoro.total : 0
  ringColor: Pomodoro.paused ? Theme.muted : role

  chipColor: role
  title: Pomodoro.title(Pomodoro.phase)
  subtitle: Pomodoro.caption()
  value: Duration.short(Pomodoro.left)

  card: Component {
    PomodoroCard {}
  }
}
