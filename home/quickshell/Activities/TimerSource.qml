import QtQuick
import qs.Commons
import qs.Services
import "../Commons/Duration.js" as Duration

// Each running timer (Services/Timers.qml) as an activity: its remaining time in the circle,
// the ring running down, and a card with the controls. One delegate per id, so a second timer
// is a second activity, and a cancelled one takes its own away.
Instantiator {
  model: Timers.ids

  delegate: Activity {
    id: act

    required property int tid

    readonly property var t: Timers.byId(tid)
    // The last timer it knew: the circle leaves with the look it had, not a blank one.
    property var seen: null
    onTChanged: if (t !== null)
      seen = t

    readonly property real left: Timers.remaining(seen)
    readonly property bool paused: seen !== null && seen.paused

    kind: "timer"
    key: "timer:" + tid
    since: seen ? seen.startedAt + tid * 0.001 : 0
    active: t !== null

    text: Duration.short(left)
    textColor: paused ? Theme.inkSecondary : Theme.inkPrimary
    ring: seen && seen.total > 0 ? left / seen.total : 0
    ringColor: paused ? Theme.muted : Theme.accent

    icon: IconPaths.timer
    chipColor: Theme.accent
    title: seen && seen.label !== "" ? seen.label : "Timer"
    subtitle: seen ? Duration.describe(seen.total) + " timer" : ""
    value: Duration.short(left)

    Component.onCompleted: seen = t

    card: Component {
      TimerCard {
        timerId: act ? act.tid : 0
      }
    }
  }
}
