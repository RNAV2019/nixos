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

  // Timed lyrics of songs that have played, one file a song (Services/Lyrics.qml).
  readonly property string lyricsDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/quickshell/lyrics"

  Process {
    command: ["mkdir", "-p", root.stateDir, root.lyricsDir]
    running: true
  }
}
