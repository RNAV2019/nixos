pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")

  // The wallpaper pool theme-switch links from, and per-theme folders the pickers list.
  readonly property string wallpaperDir: home + "/.local/share/wallpaper"
  readonly property string backgroundsDir: home + "/Pictures/backgrounds"
}
