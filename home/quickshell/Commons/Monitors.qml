pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Per-screen surfaces need the focused output; Hyprland reports it by monitor name.
Singleton {
  id: root

  // The focused output's name, or empty when Hyprland names none.
  readonly property string focusedName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

  function isFocused(screen) {
    return screen !== null && Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === screen.name;
  }
}
