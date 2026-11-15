import QtQuick
import qs.Commons

// A LyricStyle seen as an old print run through a projector: black and white, soft and
// glowing, its blacks lifted to a grainy grey, with dust, scratches and the lamp's flicker (the
// lens's `mono`, `veil`, `softness`, `dust`, `flicker`, and a heavy bloom for the halo round
// white type). This is the one look on the stage whose ground is not black: the print it copies
// has none. Its greys are toned the cover's way (the stage's `tone`), as a print is with sepia,
// so even without colour it is this song's. The styles built on it (Reel,
// Ring, Titlecard) are the set pieces of one hand-made lyric film; they share this look so a
// song can pass through all three and still seem one reel.
//
// The look is the stage's to bring up, not this style's to switch on: which stretches of the
// song are a print is in the plan (the catalogue's `look: "film"`), and the lens goes over to
// Theme's `lyricFilm...` settings across the change, along the song's time. What is set here
// says the same thing for whoever reads a style's look off it.
LyricStyle {
  bloom: Theme.lyricFilmBloom
  bloomKick: 0.12
  grain: Theme.lyricFilmGrain
  vignette: Theme.lyricFilmVignette
  ground: Theme.lyricFilmGround
  veil: Theme.lyricFilmVeil
  softness: Theme.lyricFilmSoftness
  mono: 1
  dust: 1
  flicker: 1

  // How often a letter that is up blinks out, and the grey a word arrives in before it is lit.
  readonly property real blink: 0.012
  readonly property color unlit: Qt.rgba(ink.r, ink.g, ink.b, 0.5)
}
