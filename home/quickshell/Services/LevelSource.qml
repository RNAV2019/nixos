import QtQuick
import Quickshell

// What the OSD needs to know about one adjustable level: brightness, volume and the rest
// implement this, so the OSD reads them all the same way. A singleton file takes this as
// its root type, since Singleton is the base here.
Singleton {
  // 0..1; an implementation clamps what it reads.
  property real value: 0
  property bool available: false

  // A ligature name from Icons.
  property string glyph: ""

  readonly property string percent: Math.round(value * 100) + "%"
  property string reading: percent

  // The level is a state, not an amount, so the OSD draws no fill for it (muted).
  property bool stateOnly: false

  // The state must not be misread, so the OSD outlines it in urgent (a muted microphone).
  property bool alarming: false

  // Flash the OSD for this source. Emitted exactly when a change is worth showing; the OSD
  // keeps its own startup suppression, so a source does not hold back its first changes.
  // `pressed` marks a keypress, which shows even during that suppression.
  signal adjusted(bool pressed)

  // A source with nothing to step or set keeps these no-ops.
  function step(up) {
  }

  function set(v) {
  }
}
