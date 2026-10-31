pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons

// The default sink as a level source: the OSD's reads of its volume and mute, and the wpctl
// calls the volume keys make. The bar and audio panel still read their nodes from Pipewire
// directly.
LevelSource {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var sinkAudio: sink ? sink.audio : null

  // Raw, so a volume pushed past 100% still counts as a change; `value` is clamped.
  readonly property real volume: sinkAudio ? sinkAudio.volume : 0
  readonly property bool muted: sinkAudio ? sinkAudio.muted : false

  available: sinkAudio !== null
  value: Theme.clamp01(volume)
  glyph: glyphFor(sink)
  reading: muted ? "Muted" : percent
  stateOnly: muted

  // Pipewire only delivers a node's properties while something tracks it.
  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // Any client's change shows, not only the keys'.
  onVolumeChanged: root.adjusted()
  onMutedChanged: root.adjusted()

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
    // Per keypress even at the rail, so the OSD can appear without waiting on a Pipewire
    // change that never comes.
    root.adjusted();
  }

  function set(v) {
    if (sinkAudio)
      sinkAudio.volume = Theme.clamp01(v);
  }

  // The glyph a sink shows: muted, or the ladder step for its level. `node` is any
  // Pipewire node, or null, and the OSD, bar and audio panel all read the same answer.
  function glyphFor(node) {
    var audio = node && node.audio ? node.audio : null;
    var muted = audio !== null && audio.muted;
    var level = audio !== null ? audio.volume * 100 : 0;
    return muted ? Icons.volumeMuted : Icons.step(Icons.volume, level);
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
