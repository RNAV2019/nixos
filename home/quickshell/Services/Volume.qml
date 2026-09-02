pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Writes only. The OSD, bar widget and audio panel each read the sink straight
// from Pipewire, so this singleton exists to own the wpctl calls the volume
// keys make and to announce them.
Singleton {
  id: root

  // Emitted per keypress, including when the volume is already railed, so the
  // OSD can appear without waiting on a Pipewire change that never comes.
  signal adjusted

  function step(up) {
    // -l caps boosting at 100%; without it wpctl walks past unity.
    setter.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", up ? "5%+" : "5%-", "-l", "1.0"];
    setter.running = true;
    root.adjusted();
  }

  Process {
    id: setter
  }
}
