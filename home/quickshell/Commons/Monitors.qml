pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Per-screen surfaces need the focused output; Hyprland reports it by monitor name.
Singleton {
  id: root

  // Empty with no Hyprland to ask.
  readonly property string focusedName: Hyprland.focusedMonitor !== null ? Hyprland.focusedMonitor.name : ""

  function isFocused(screen) {
    return screen !== null && Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === screen.name;
  }
}
