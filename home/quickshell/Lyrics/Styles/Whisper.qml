import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Close to the ear. The line is set small and centred in a serif italic, and each word is
// breathed out a letter at a time: the letters rise into place and fade up across the word's
// own length, gathering in from loose as they come. The word being sung glows in the cover's
// colour and cools to ink once it is done; the line before lingers above, smaller and fainter,
// drifting up and away.
LyricStyle {
  id: sty

  bloom: 0.7
  bloomKick: 0.12
  aberration: 0.0006
  aberrationKick: 0.0012
  warp: 0.35
  grain: 0.04
  vignette: 0.55
  ground: 0.8

  // The face's size, set once; a line is fitted with `scale`.
  readonly property real size: 9 * u
  readonly property real room: width * 0.72
  readonly property real lineH: size * 1.16
  readonly property int maxRows: 3
  // How far a word's letters spread before they gather, per letter.
  readonly property real loose: 0.45 * u
  // Where the line in hand sits, as a share of the height.
  readonly property real centre: 0.53

  FontMetrics {
    id: metrics

    font.family: Theme.lyricSerifFont
    font.italic: true
    font.weight: Font.Normal
    font.pixelSize: Math.max(1, Math.round(sty.size))
  }

  // A line laid out for the stage: its words wrapped into at most three centred rows of about
  // equal length, each word's letters placed by their own advances (the letters are drawn one
  // by one, so the word is measured the same way), and the scale that keeps it all in the room.
  function layout(i) {
    if (i < 0 || metrics.height <= 0)
      return null;
    var words = lines[i].words;
    var space = metrics.advanceWidth(" ") * 1.05;
    var placed = words.map(function (w) {
      var letters = [];
      var x = 0;
      Array.from(String(w.text)).forEach(function (ch) {
        letters.push({
          ch: ch,
          x: x
        });
        x += metrics.advanceWidth(ch);
      });
      return {
        letters: letters,
        w: x
      };
    });
    var wrap = function (limit) {
      var rows = [];
      var row = [], run = 0;
      for (var j = 0; j < placed.length; j++) {
        var add = (row.length > 0 ? space : 0) + placed[j].w;
        if (row.length > 0 && run + add > limit) {
          rows.push({
            words: row,
            w: run
          });
          row = [];
          run = 0;
          add = placed[j].w;
        }
        row.push(j);
        run += add;
      }
      if (row.length > 0)
        rows.push({
          words: row,
          w: run
        });
      return rows;
    };
    // Wider than the room until it fits in three rows, then as narrow as that row count allows,
    // so a two-row line is two even rows rather than a long one and a stray word.
    var k = 1;
    var rows = wrap(room);
    while (rows.length > maxRows && k < 4) {
      k *= 1.12;
      rows = wrap(room * k);
    }
    var lo = 0, hi = room * k;
    placed.forEach(function (p) {
      lo = Math.max(lo, p.w);
    });
    for (var n = 0; n < 10 && hi - lo > 1; n++) {
      var mid = (lo + hi) / 2;
      if (wrap(mid).length <= rows.length)
        hi = mid;
      else
        lo = mid;
    }
    rows = wrap(Math.max(hi, lo));
    var widest = 1;
    rows.forEach(function (r) {
      widest = Math.max(widest, r.w);
    });
    var out = [];
    rows.forEach(function (r, ri) {
      var x = (widest - r.w) / 2;
      r.words.forEach(function (j) {
        out.push({
          w: words[j],
          x: x,
          y: ri * lineH,
          letters: placed[j].letters
        });
        x += placed[j].w + space;
      });
    });
    return {
      words: out,
      w: widest,
      h: rows.length * lineH,
      scale: Math.min(1, room / widest)
    };
  }

  // The line in hand's height on the stage, for the one before to clear.
  readonly property var curLayout: layout(cur)
  readonly property real curHalf: curLayout ? curLayout.h * curLayout.scale / 2 : 5 * u

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      // Only the line in hand and the one before draw; the one after waits with no items.
      readonly property bool live: line !== null && lineIndex <= sty.cur
      readonly property var lay: live ? sty.layout(lineIndex) : null
      readonly property var next: line && lineIndex + 1 <= sty.last ? sty.lines[lineIndex + 1] : null
      // When it gives up the middle: as the next line comes, or at its own leaving.
      readonly property real leaveAt: line ? Math.min(line.out, next ? next.t - sty.lead : Infinity) : 0
      readonly property real gone: sty.now - leaveAt
      readonly property bool above: gone >= 0
      readonly property real up: Kinetic.outCubic(gone / 0.9)
      readonly property real fade: 1 - Kinetic.smooth(1.1, 3.4, gone)
      readonly property real shrink: Kinetic.lerp(1, 0.58, up)
      readonly property real scaleNow: lay ? lay.scale * shrink : 1
      // Above the line in hand, its bottom a little clear of that line's top.
      readonly property real home: sty.height * sty.centre
      readonly property real perch: home - (sty.cur !== lineIndex ? sty.curHalf : 0) - 3.2 * sty.u - (lay ? lay.h * scaleNow / 2 : 0)

      anchors.fill: parent
      visible: lay !== null && sty.now >= line.words[0].t - 0.05 && fade > 0.001
      opacity: Kinetic.lerp(1, 0.34, up) * fade

      Item {
        id: block

        width: slot.lay ? slot.lay.w : 0
        height: slot.lay ? slot.lay.h : 0
        x: (sty.width - width) / 2 + Math.sin(sty.stage.wall * 0.21 + slot.index * 2.1) * 0.5 * sty.u
        y: Kinetic.lerp(slot.home, slot.perch, slot.up) - 5 * sty.u * Kinetic.smooth(0.7, 3.4, slot.gone) - height / 2
        // A breath in over the line's life.
        scale: slot.scaleNow * (1 + 0.018 * (slot.line ? Kinetic.span(slot.line.t, slot.line.out, sty.now) : 0))

        Repeater {
          model: slot.lay ? slot.lay.words : []

          Item {
            id: word

            required property var modelData

            readonly property var w: modelData.w
            readonly property real age: sty.now - w.t
            readonly property real gather: Kinetic.outCubic(age / (w.d + 0.5))
            readonly property color tint: sty.mix(sty.accent, sty.ink, (age - w.d) / 1.1)

            x: modelData.x
            y: modelData.y
            visible: age >= 0

            // Letter by letter while it is the line in hand.
            Repeater {
              model: slot.above ? [] : word.modelData.letters

              LyricText {
                id: letter

                required property var modelData
                required property int index

                readonly property int count: word.modelData.letters.length
                readonly property real age: word.age - word.w.d * 0.85 * index / Math.max(1, count)
                readonly property real rise: Kinetic.spring(age, 10, 1)

                x: modelData.x + index * sty.loose * (1 - word.gather)
                y: (1 - rise) * 1.8 * sty.u
                visible: age > 0
                opacity: Kinetic.smooth(0, 0.38, age)
                text: modelData.ch
                size: sty.size
                font.family: Theme.lyricSerifFont
                font.weight: Font.Normal
                font.italic: true
                color: word.tint
              }
            }

            // Whole, once it has gone up to linger.
            LyricText {
              visible: slot.above
              text: word.w.text
              size: sty.size
              font.family: Theme.lyricSerifFont
              font.weight: Font.Normal
              font.italic: true
              color: word.tint
            }
          }
        }
      }
    }
  }
}
