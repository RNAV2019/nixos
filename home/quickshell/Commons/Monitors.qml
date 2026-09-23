pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Per-screen surfaces need the focused output; Hyprland reports it by monitor name.
Singleton {
  id: root

  function isFocused(screen) {
    return screen !== null && Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === screen.name;
  }
}
