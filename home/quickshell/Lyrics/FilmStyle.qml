import QtQuick

// A LyricStyle seen as an old print run through a projector: black and white, soft and
// glowing, with dust, scratches, grain and the lamp's flicker (the lens's `mono`, `dust`,
// `flicker`, and a heavy bloom for the halo round white type). The styles built on it (Reel,
// Ring, Titlecard) are the set pieces of one hand-made lyric film; they share this look so a
// song can pass through all three and still seem one reel.
LyricStyle {
  bloom: 1.0
  bloomKick: 0.12
  grain: 0.2
  vignette: 0.62
  ground: 0.7
  mono: 1
  dust: 1
  flicker: 1
  cutFlash: 2.4

  // How often a letter that is up blinks out, and the grey a word arrives in before it is lit.
  readonly property real blink: 0.012
  readonly property color unlit: Qt.rgba(ink.r, ink.g, ink.b, 0.5)
}
