pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Writes only: the OSD, bar and audio panel read the sink from Pipewire directly, so this
// singleton owns the wpctl calls the volume keys make and announces them.
Singleton {
  id: root

  // Emitted per keypress even at the rail, so the OSD can appear without waiting on
  // a Pipewire change that never comes.
  signal adjusted

  // Key repeat can outpace wpctl: a signed pending delta preserves the net change and
  // lets opposite presses cancel before a process starts.
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
