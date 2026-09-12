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

  // Key repeat can outpace wpctl. A signed pending delta preserves the net change while
  // allowing opposite presses to cancel before a process is started.
  readonly property int stepPercent: 5
  readonly property int writeInterval: 20
  property int _pendingPercent: 0
  property real _lastWriteAt: 0

  function flush() {
    if (_pendingPercent === 0 || setter.running)
      return;

    var elapsed = Date.now() - _lastWriteAt;
    if (_lastWriteAt > 0 && elapsed < writeInterval) {
      writeTimer.restart();
      return;
    }

    var delta = _pendingPercent;
    _pendingPercent = 0;
    _lastWriteAt = Date.now();
    setter.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.abs(delta) + "%" + (delta > 0 ? "+" : "-"), "-l", "1.0"];
    setter.running = true;
  }

  function step(up) {
    _pendingPercent += up ? stepPercent : -stepPercent;
    writeTimer.restart();
    root.adjusted();
  }

  Timer {
    id: writeTimer

    interval: root.writeInterval
    repeat: false
    onTriggered: root.flush()
  }

  Process {
    id: setter

    onRunningChanged: if (!setter.running)
      root.flush()
  }
}
