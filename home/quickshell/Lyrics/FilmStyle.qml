import QtQuick

// A LyricStyle seen as an old print run through a projector: black and white, soft and
// glowing, its blacks lifted to a grainy grey, with dust, scratches and the lamp's flicker (the
// lens's `mono`, `veil`, `softness`, `dust`, `flicker`, and a heavy bloom for the halo round
// white type). This is the one look on the stage whose ground is not black: the print it copies
// has none. The styles built on it (Reel,
// Ring, Titlecard) are the set pieces of one hand-made lyric film; they share this look so a
// song can pass through all three and still seem one reel.
LyricStyle {
  bloom: 1.1
  bloomKick: 0.12
  grain: 0.34
  vignette: 0.74
  ground: 0.75
  veil: 0.13
  softness: 1.7
  mono: 1
  dust: 1
  flicker: 1
  cutFlash: 2.4

  // How often a letter that is up blinks out, and the grey a word arrives in before it is lit.
  readonly property real blink: 0.012
  readonly property color unlit: Qt.rgba(ink.r, ink.g, ink.b, 0.5)
}
