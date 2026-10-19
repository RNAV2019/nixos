pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock on the main keyboard. Hyprland is the only source that tracks the keyd virtual
// keyboard's lock state, and there is no event for it, so callers ask with check() whenever
// it matters (the lock screen does on every key and on a slow beat besides).
Singleton {
  id: root

  property bool capsLock: false

  function check() {
    if (!query.running)
      query.running = true;
  }

  Process {
    id: query

    command: ["hyprctl", "devices", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var keyboards = JSON.parse(this.text).keyboards || [];
          var main = keyboards.find(k => k.main) || keyboards[0];
          root.capsLock = !!(main && main.capsLock);
        } catch (e) {
          root.capsLock = false;
        }
      }
    }
  }
}
