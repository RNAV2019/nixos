import QtQuick
import Quickshell

// Every source of live activities and moments, started once with the shell. A new source is a
// file in this directory (an Activity, or an Instantiator of them, like TimerSource) added here.
Scope {
  id: root

  // The plugged-in watcher, for the shell's test IPC to override.
  readonly property alias plugged: plugged

  TimerSource {}

  PomodoroSource {}

  PluggedSource {
    id: plugged
  }

  ClaudeSource {}

  RebuildSource {}

  UsbSource {}

  DemoSource {}
}
