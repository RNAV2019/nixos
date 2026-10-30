import QtQuick
import qs.Commons
import qs.Services

// Stand-in activities for driving the satellites without their owners (`qs ipc call activities
// demo <name>`), so the slots, the attention pulse and the "+N" list can be seen before the
// real sources exist: "phone" (pinned, a battery ring), "event" (minutes to go, gold),
// "alert" (needs you: a gold ground and its halo) and "build" (work of unknown length).
Instantiator {
  model: Activities.demos

  delegate: Activity {
    id: demo

    required property string modelData
    required property int index

    readonly property bool phone: modelData === "phone"
    readonly property bool event: modelData === "event"
    readonly property bool alert: modelData === "alert"

    kind: "demo-" + modelData
    key: "demo:" + modelData
    pinned: phone
    attention: alert

    icon: phone ? IconPaths.smartphone : alert ? IconPaths.timer : IconPaths.check
    iconColor: alert ? Theme.inkOnAccent : Theme.inkPrimary
    text: event ? "12" : ""
    textColor: Theme.gold
    textSize: 14
    caption: event ? "min" : ""
    ring: phone ? 0.78 : -1
    indeterminate: modelData === "build"
    ground: alert ? Theme.gold : Theme.surface
    haloColor: Theme.gold

    chipColor: alert || event ? Theme.gold : Theme.accent
    title: phone ? "Phone" : event ? "Standup" : alert ? "Starting now" : "Building"
    subtitle: "A stand-in"
    value: phone ? "78%" : event ? "12m" : ""
  }
}
