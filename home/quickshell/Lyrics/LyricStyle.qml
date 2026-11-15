import QtQuick
import qs.Commons
import "Kinetic.js" as Kinetic
import "Parse.js" as Parse

// What every style on the lyric stage is built on (Lyrics/Styles/*.qml). A style is handed the
// stage and one segment of the song, and draws that segment's lines from the song's own time
// (`now`): every position, size and fade is a function of `now` (Kinetic.js), never a running
// animation, so a seek, a pause and a pinned test frame all show the same picture.
//
// A style also says how the lens should treat it: the numbers below are read by LyricScene and
// handed to Shaders/lyricpost.frag. The `...Kick` ones are added in proportion to the stage's
// `kick`, which jumps as each word lands and dies away.
Item {
  id: sty

  required property var stage
  required property var seg

  readonly property real now: stage.now
  // The song's lines as they were when this style was cast: a style on its way out at a change
  // of song goes on reading its own song.
  required property var lines
  readonly property int first: seg.firstLine
  readonly property int last: seg.lastLine
  readonly property int seed: seg.seed
  // One hundredth of the stage's height: the unit styles size themselves in.
  readonly property real u: height / 100

  readonly property color ink: stage.ink
  readonly property color accent: stage.accent
  readonly property color accent2: stage.accent2

  // How early a line counts as the one in hand.
  property real lead: Theme.lyricLead
  // The segment's line in hand, or -1 before its first.
  readonly property int cur: {
    if (first < 0)
      return -1;
    var i = Parse.lineAt(lines, now, lead);
    return i < first ? -1 : Math.min(i, last);
  }
  readonly property var line: cur >= 0 ? lines[cur] : null

  // The lens.
  property real bloom: 0.45
  property real bloomKick: 0.3
  property real aberration: 0.0012
  property real aberrationKick: 0.003
  property real punchKick: 0
  property real glitchKick: 0
  property real shakeKick: 0
  property real flashKick: 0
  property real warp: 0
  property real scan: 0
  property real grain: 0.05
  property real vignette: 0.4
  // An old print: colour drained, dust and scratches, the lamp's flicker, and the lamp itself
  // as a soft disc at `spotAt` (0..1 across and down), `spotSize` stage heights in radius.
  property real mono: 0
  property real dust: 0
  property real flicker: 0
  property real spot: 0
  property real spotSize: 0.32
  property point spotAt: Qt.point(0.5, 0.5)
  // How hard the cut into this style lifts the frame, against the usual.
  property real cutFlash: 1
  // The ground's light behind this style, as a share of the stage's own.
  property real ground: 1

  // The line a pool's slot `k` of `n` draws, or -1: the pool covers the line in hand, the
  // `n - 2` before it and the one after, each line always in the same slot, so a line keeps its
  // items from the moment it is due until it is well gone.
  function slotLine(k, n) {
    if (first < 0)
      return -1;
    var base = cur < 0 ? first - 1 : cur;
    for (var i = base - (n - 2); i <= base + 1; i++)
      if (i >= first && i <= last && ((i % n) + n) % n === k)
        return i;
    return -1;
  }

  // A face for the `j`th word of line `i`, the same every time this segment plays.
  function face(i, j) {
    return Kinetic.pick(Theme.lyricFaces, seed, i, j);
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
}
