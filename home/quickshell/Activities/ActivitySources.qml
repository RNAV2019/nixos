import QtQuick
import Quickshell

// Every source of moments, started once with the shell. A new source is a file in this directory
// added here.
Scope {
  id: root

  // The plugged-in and sign-in watchers, for the shell's test IPC to override.
  readonly property alias plugged: plugged
  readonly property alias wifi: wifi

  WifiSource {
    id: wifi
  }

  PluggedSource {
    id: plugged
  }
}
