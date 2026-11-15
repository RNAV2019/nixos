import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The word in hand, huge, in heavy capitals, with a trail of its own echoes behind it. When the
// word lands the echoes spring out of it one after another along a slant, each fainter and
// further into the cover's colours, so the hit ripples away from it; as the word gives way
// they fold back into it. The line runs small above, filling in as it is sung.
LyricStyle {
  id: sty

  bloom: 0.55
  bloomKick: 0.5
  aberration: 0.0016
  aberrationKick: 0.009
  punchKick: 0.75
  shakeKick: 0.35
  flashKick: 0.02
  grain: 0.06
  vignette: 0.5
  ground: 1.1

  // How many echoes trail a word.
  readonly property int echoes: 6
  // How long a word takes to leave once the next has landed.
  readonly property real exit: 0.1

  // The segment's words in order, so a pool of three can take them in turn.
  readonly property var words: {
    var out = [];
    if (first < 0)
      return out;
    for (var i = first; i <= last; i++)
      for (var j = 0; j < lines[i].words.length; j++)
        out.push({
          li: i,
          j: j
        });
    return out;
  }
  // The word in hand: the last to have begun.
  readonly property int at: {
    var c = -1;
    for (var n = 0; n < words.length; n++)
      if (lines[words[n].li].words[words[n].j].t <= now + 0.02)
        c = n;
    return c;
  }

  // The ways a trail can run, as a unit step (x, y). Each word takes one.
  readonly property var ways: [[0.8, 0.6], [-0.8, 0.6], [0, 1], [0.8, -0.6], [-0.8, -0.6], [0, -1]]

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      // Of the word before, the one in hand and the one after, the one whose turn is this slot's.
      readonly property int n: {
        for (var m = sty.at - 1; m <= sty.at + 1; m++)
          if (m >= 0 && m < sty.words.length && m % 3 === index)
            return m;
        return -1;
      }
      readonly property var line: n >= 0 ? sty.lines[sty.words[n].li] : null
      readonly property int j: n >= 0 ? sty.words[n].j : 0
      readonly property var word: line && j < line.words.length ? line.words[j] : null
      readonly property real age: word ? sty.now - word.t : -1
      readonly property real until: line ? sty.until(line, j) : 0
      readonly property real gone: sty.now - until
      readonly property bool loud: word ? (word.d > 0.45 || j === line.words.length - 1) : false
      readonly property var way: sty.ways[Math.floor(Kinetic.hash(sty.seed, n, 5) * sty.ways.length)]
      readonly property real land: Kinetic.spring(age, 26, 0.55)
      // The echoes fold back in just before the next word.
      readonly property real close: Kinetic.smooth(until - Math.min(0.18, (until - (word ? word.t : 0)) * 0.3), until, sty.now)
      readonly property real leave: Kinetic.outCubic(gone / sty.exit)
      // One step of the trail: a share of the word's own height, shorter where a wide word leaves
      // the trail no room across.
      readonly property real step: Math.min((loud ? 0.2 : 0.15) * main.height * main.scale, (sty.width * 0.95 - main.width * main.scale) / Math.max(0.01, sty.echoes * Math.abs(way[0])), (76 * sty.u - main.height * main.scale) / Math.max(0.01, sty.echoes * Math.abs(way[1])))

      anchors.fill: parent
      visible: word !== null && age > -0.02 && gone < sty.exit
      opacity: Kinetic.clamp01(age / 0.04) * (1 - leave)

      // The group is centred as a whole: the word moves back along its trail by half its reach.
      readonly property real reach: sty.echoes * step * (1 - close) * Kinetic.spring(age - 0.1, 14, 0.8)
      readonly property real cx: width / 2 - way[0] * reach / 2
      readonly property real cy: height * 0.54 - way[1] * reach / 2

      // Farthest first, so the nearer echoes sit over it.
      Repeater {
        model: sty.echoes

        LyricText {
          required property int index

          // The furthest echo is the last to be let go, so the spread ripples outward.
          readonly property int k: sty.echoes - 1 - index
          readonly property real out: Kinetic.spring(slot.age - 0.03 * k, 22, 0.42) * (1 - slot.close)
          readonly property real d: (k + 1) * slot.step * out

          x: slot.cx + slot.way[0] * d - width / 2
          y: slot.cy + slot.way[1] * d - height / 2
          text: main.text
          caps: true
          size: main.size
          font.family: main.font.family
          font.weight: main.font.weight
          font.letterSpacing: main.font.letterSpacing
          color: sty.mix(sty.accent, sty.accent2, k / (sty.echoes - 1))
          opacity: 0.75 * Math.pow(0.7, k) * Kinetic.clamp01(out * 3)
          scale: main.scale * (1 - 0.03 * (k + 1) * out)
        }
      }

      LyricText {
        id: main

        // Fitted once: as wide as the stage lets it be with room for the trail, as tall as a
        // loud word may be.
        readonly property real fit: Math.min(sty.width * 0.76 / Math.max(1, implicitWidth), (slot.loud ? 46 : 38) * sty.u / Math.max(1, implicitHeight))

        x: slot.cx - width / 2
        y: slot.cy - height / 2
        text: slot.word ? Kinetic.bare(slot.word.text) : ""
        caps: true
        size: 20 * sty.u
        font.family: Theme.lyricGroteskFont
        font.weight: Font.Normal
        font.letterSpacing: -0.04 * size
        color: sty.mix(sty.accent, sty.ink, slot.age / 0.25)
        scale: fit * (1.18 - 0.18 * slot.land) * (1 - 0.12 * slot.leave)
      }
    }
  }

  // The line, small, above the word: sung words in ink, the one in hand in the accent, the
  // rest waiting dim.
  LyricText {
    id: context

    readonly property real up: sty.line ? Kinetic.span(sty.line.t - sty.lead, sty.line.t, sty.now) * (1 - Kinetic.span(sty.line.out, sty.line.out + 0.25, sty.now)) : 0
    readonly property real fit: Math.min(1, sty.width * 0.86 / Math.max(1, implicitWidth))

    function esc(s) {
      return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    anchors.horizontalCenter: parent.horizontalCenter
    y: 13 * sty.u - height / 2
    scale: fit
    opacity: up
    visible: up > 0
    textFormat: Text.StyledText
    caps: true
    size: 2.8 * sty.u
    font.family: Theme.lyricGroteskFont
    font.weight: Font.Normal
    font.letterSpacing: 0.35 * sty.u
    text: {
      var l = sty.line;
      if (!l)
        return "";
      var ink = sty.ink.toString();
      var lead = sty.accent.toString();
      var dim = Qt.rgba(sty.ink.r, sty.ink.g, sty.ink.b, 0.22).toString();
      var out = "";
      for (var i = 0; i < l.words.length; i++) {
        var w = l.words[i];
        var c = w.t > sty.now ? dim : sty.now < sty.until(l, i) && sty.now < w.t + w.d + 0.3 ? lead : ink;
        out += (i > 0 ? " " : "") + "<font color=\"" + c + "\">" + esc(w.text) + "</font>";
      }
      return out;
    }
  }
}
