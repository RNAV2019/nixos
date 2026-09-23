pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

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

  // The glyph a sink shows: muted, or the ladder step for its level. `sink` is any
  // Pipewire node, or null, and the OSD, bar and audio panel all read the same answer.
  function glyph(sink) {
    var audio = sink && sink.audio ? sink.audio : null;
    var muted = audio !== null && audio.muted;
    var percent = audio !== null ? audio.volume * 100 : 0;
    return muted ? Icons.volumeMuted : Icons.step(Icons.volume, percent);
  }

  Timer {
    id: writeTimer

    interval: root.writeInterval
    repeat: false
    onTriggered: root.flush()
  }

  Process {
    id: setter

    property string errorText: ""

    stderr: StdioCollector {
      onStreamFinished: setter.errorText = text
    }

    onRunningChanged: if (!setter.running)
      root.flush()

    onExited: function (code) {
      if (code !== 0) {
        var said = setter.errorText.trim();
        console.warn("wpctl set-volume:", said !== "" ? said : "exit code " + code);
      }
    }
  }
}
