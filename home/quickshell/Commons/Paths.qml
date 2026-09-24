pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")

  // The wallpaper pool theme-switch links from, and per-theme folders the pickers list.
  readonly property string wallpaperDir: home + "/.local/share/wallpaper"
  readonly property string backgroundsDir: home + "/Pictures/backgrounds"

  // Where the shell's own toggles keep their saved state. Created at startup, since
  // FileView cannot make parent directories itself.
  readonly property string stateDir: home + "/.local/state/shell"

  Process {
    command: ["mkdir", "-p", root.stateDir]
    running: true
  }
}
