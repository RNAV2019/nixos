pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Per-screen surfaces need to know which output the compositor considers
// focused; Hyprland reports that by monitor name.
Singleton {
  id: root

  function isFocused(screen) {
    return screen !== null && Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === screen.name;
  }
}
