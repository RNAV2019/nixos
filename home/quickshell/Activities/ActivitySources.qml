import QtQuick
import Quickshell

// Every source of live activities and moments, started once with the shell. A new source is a
// file in this directory (an Activity, or an Instantiator of them, like TimerSource) added here.
Scope {
  id: root

  // The plugged-in, next-event and sign-in watchers, for the shell's test IPC to override.
  readonly property alias plugged: plugged
  readonly property alias event: event
  readonly property alias wifi: wifi

  TimerSource {}

  PomodoroSource {}

  EventSource {
    id: event
  }

  WifiSource {
    id: wifi
  }

  PluggedSource {
    id: plugged
  }

  ClaudeSource {}

  RebuildSource {}

  UsbSource {}

  DemoSource {}
}
