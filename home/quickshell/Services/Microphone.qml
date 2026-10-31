pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons

// The default source's mute, as a level source. Mute is a state here, not a level, so the
// OSD draws no fill and outlines it when the microphone is off.
LevelSource {
  id: root

  readonly property var source: Pipewire.defaultAudioSource
  readonly property var sourceAudio: source ? source.audio : null
  readonly property bool muted: sourceAudio ? sourceAudio.muted : false

  available: sourceAudio !== null
  value: sourceAudio ? Theme.clamp01(sourceAudio.volume) : 0
  glyph: muted ? Icons.microphoneMuted : Icons.microphone
  reading: muted ? "Mic off" : "Mic on"
  stateOnly: true
  alarming: muted

  // Pipewire only delivers a node's properties while something tracks it.
  PwObjectTracker {
    objects: root.source ? [root.source] : []
  }

  onMutedChanged: root.adjusted()
}
