import QtQuick
import qs.Commons
import "Kinetic.js" as Kinetic
import "Parse.js" as Parse

// What every style on the lyric stage is built on (Lyrics/Styles/*.qml). A style is handed the
// stage and a song's lines, and draws them from the song's own time (`now`): every position,
// size and fade is a function of `now` (Kinetic.js), never a running animation, so a seek, a
// pause and a pinned test frame all show the same picture.
//
// A style also says how the lens should treat it: `depth`, `depthAt` and `depthBand` are read
// by LyricScene every frame and handed to Shaders/lyricpost.frag.
Item {
  id: sty

  required property var stage
  // The song's lines as they were when this style was put up: a style on its way out at a
  // change of song goes on reading its own song.
  required property var lines

  readonly property real now: stage.now
  // One hundredth of the stage's height: the unit styles size themselves in.
  readonly property real u: height / 100

  // The song's colours, off its cover (Palette.js): what words are set in, the word in hand,
  // and a word not yet sung.
  readonly property color ink: stage.ink
  readonly property color accent: stage.accent
  readonly property color dim: stage.dim

  // How early a line counts as the one in hand.
  property real lead: Theme.lyricLead
  // The line in hand, or -1 before the song's first.
  readonly property int cur: lines.length > 0 ? Parse.lineAt(lines, now, lead) : -1
  readonly property var line: cur >= 0 ? lines[cur] : null

  // The lens: everything above and below a band of the stage out of focus. `depthAt` is the
  // band's middle as a height (0..1), `depthBand` half the band, `depth` how soft the rest is.
  property real depth: 0
  property real depthAt: 0.5
  property real depthBand: 0.08
  // The ground's light behind this style, as a share of the stage's own.
  property real ground: 1

  // The line a pool's slot `k` of `n` draws, or -1. The pool covers the line in hand, the
  // `after` lines that follow it and the `n - 1 - after` before it, each line always in the
  // same slot, so a line keeps its items from the moment it is due until it is well gone.
  function slotLine(k, n, after) {
    var ahead = after === undefined ? 1 : after;
    for (var i = cur - (n - 1 - ahead); i <= cur + ahead; i++)
      if (i >= 0 && i < lines.length && ((i % n) + n) % n === k)
        return i;
    return -1;
  }

  // `a` on its way to `b`, `t` of the way there.
  function mix(a, b, t) {
    var k = Kinetic.clamp01(t);
    return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, a.a + (b.a - a.a) * k);
  }

  // When word `j` of `line` gives way: the next word's start, or the line's own leaving.
  function until(line, j) {
    return j + 1 < line.words.length ? line.words[j + 1].t : line.out;
  }

  // When word `j` of `line` has been sung: the next word's start, or the line's end.
  function sung(line, j) {
    return j + 1 < line.words.length ? line.words[j + 1].t : line.end;
  }

  // A line with a pause after it: it is held a moment and then goes, where a line the next
  // one follows closely is simply replaced by it.
  function parting(line) {
    var next = line.index + 1 < lines.length ? lines[line.index + 1] : null;
    return next === null || line.out < next.t - 0.01;
  }
}
