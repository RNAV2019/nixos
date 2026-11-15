import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The lines on a wall seen from the side. The wall is turned away to the right and tipped back
// a little, swaying slowly; the line in hand is large on it and fills word by word, each word
// wiped from dim to full ink as it is sung, the word in the voice lifted and in the cover's
// colour. Sung lines slide up the wall and away, smaller and fainter, and the next waits dim
// below.
LyricStyle {
  id: sty

  bloom: 0.45
  bloomKick: 0.22
  aberration: 0.0011
  aberrationKick: 0.0025
  punchKick: 0.05
  grain: 0.05
  vignette: 0.5
  ground: 0.9

  readonly property real size: 9 * u
  readonly property real rowH: size * 1.08
  readonly property real room: width * 0.7
  readonly property real gap: 3.2 * u
  readonly property real inset: width * 0.21
  // Where the middle of the line in hand sits on the wall.
  readonly property real home: height * 0.5

  FontMetrics {
    id: metrics

    font.family: Theme.lyricDisplayFont
    font.weight: Font.Bold
    font.pixelSize: Math.max(1, Math.round(sty.size))
  }

  // A line's words in rows: one row unless it is much wider than the wall, then two or three of
  // about equal width; and the scale that brings the widest row to the wall's width.
  function layout(i) {
    if (i < first || i > last)
      return null;
    var words = lines[i].words;
    var space = metrics.advanceWidth(" ");
    var widths = words.map(function (w) {
      return metrics.advanceWidth(String(w.text));
    });
    var total = space * (words.length - 1);
    widths.forEach(function (w) {
      total += w;
    });
    var n = Math.min(words.length, total > room * 2.5 ? 3 : total > room * 1.25 ? 2 : 1);
    var rows = [];
    var row = [], run = 0, done = 0;
    for (var j = 0; j < words.length; j++) {
      var add = (row.length > 0 ? space : 0) + widths[j];
      var left = n - rows.length - 1;
      if (row.length > 0 && left > 0 && (done + run + add / 2 > total * (rows.length + 1) / n || words.length - j <= left)) {
        rows.push(row);
        done += run + space;
        row = [];
        run = 0;
        add = widths[j];
      }
      row.push(j);
      run += add;
    }
    rows.push(row);
    var widest = 1;
    rows.forEach(function (r) {
      var w = space * (r.length - 1);
      r.forEach(function (k) {
        w += widths[k];
      });
      widest = Math.max(widest, w);
    });
    var fit = Math.min(1, room / widest);
    // Each word carries itself and when it gives way, so a row never reaches back to the line.
    return {
      rows: rows.map(function (r) {
        return r.map(function (k) {
          return {
            w: words[k],
            end: until(lines[i], k)
          };
        });
      }),
      fit: fit,
      h: rows.length * rowH * fit
    };
  }

  readonly property var lays: {
    var m = {};
    if (cur < 0)
      return m;
    for (var i = cur - 3; i <= cur + 2; i++)
      m[i] = layout(i);
    return m;
  }

  // Each step away from the line in hand: how large and how bright.
  readonly property var sungScale: [1, 0.64, 0.44, 0.34]
  readonly property var sungLight: [1, 0.36, 0.12, 0]
  readonly property real waitScale: 0.82
  readonly property real waitLight: 0.2

  // Where line `i` stands, its top, scale and light, while line `c` is the one in hand.
  function place(i, c) {
    var hc = lays[c] ? lays[c].h : rowH;
    var top = home - hc / 2;
    if (i === c)
      return {
        y: top,
        s: 1,
        o: 1
      };
    if (i > c) {
      var y = top + hc + gap;
      for (var k = c + 1; k < i; k++)
        y += (lays[k] ? lays[k].h : rowH) * waitScale + gap;
      return {
        y: y,
        s: waitScale,
        o: i === c + 1 ? waitLight : 0
      };
    }
    var up = top;
    var step = 0;
    for (var j = c - 1; j >= i; j--) {
      step = Math.min(3, c - j);
      // A full gap under the line just sung, so it never crowds the one in hand.
      up -= gap * (step === 1 ? 1.8 : 0.8) + (lays[j] ? lays[j].h : rowH) * sungScale[step];
    }
    return {
      y: up,
      s: sungScale[step],
      o: sungLight[step]
    };
  }

  // The move from the last line to this one, let go a moment before it is sung.
  readonly property real travel: line && cur > first ? Kinetic.spring(now - (line.t - lead), 8, 0.9) : 1
  readonly property real leaving: line ? 1 - Kinetic.span(line.out - 0.25, line.out + 0.15, now) : 0

  Item {
    id: wall

    anchors.fill: parent
    visible: sty.cur >= 0

    transform: [
      Rotation {
        origin.x: wall.width / 2
        origin.y: wall.height / 2
        axis {
          x: 0
          y: 1
          z: 0
        }
        angle: 16 + 2.5 * Math.sin(sty.stage.wall * 0.15)
      },
      Rotation {
        origin.x: wall.width / 2
        origin.y: wall.height / 2
        axis {
          x: 1
          y: 0
          z: 0
        }
        angle: 5 + 1.5 * Math.sin(sty.stage.wall * 0.11 + 1.3)
      }
    ]

    Repeater {
      model: 4

      Item {
        id: slot

        required property int index

        readonly property int lineIndex: sty.slotLine(index, 4)
        readonly property var lay: lineIndex >= 0 && lineIndex >= sty.cur - 3 ? sty.lays[lineIndex] : null
        readonly property var to: lay ? sty.place(lineIndex, sty.cur) : null
        readonly property var from: lay ? sty.place(lineIndex, sty.cur > sty.first ? sty.cur - 1 : sty.cur) : null
        readonly property real t: sty.travel
        readonly property real s: to && from ? Kinetic.lerp(from.s, to.s, t) : 1
        readonly property real light: to && from ? Kinetic.lerp(from.o, to.o, t) * sty.leaving : 0

        x: sty.inset + (1 - s) * 6 * sty.u
        y: to && from ? Kinetic.lerp(from.y, to.y, t) : 0
        scale: s * (lay ? lay.fit : 1)
        transformOrigin: Item.TopLeft
        visible: lay !== null && light > 0.003
        opacity: light

        Column {
          Repeater {
            model: slot.lay ? slot.lay.rows : []

            Row {
              id: row

              required property var modelData

              height: sty.rowH
              spacing: metrics.advanceWidth(" ")

              Repeater {
                model: row.modelData

                Item {
                  id: word

                  required property var modelData

                  readonly property var w: modelData.w
                  readonly property real fill: Kinetic.span(w.t, w.t + Math.max(0.08, w.d * 0.9), sty.now)
                  readonly property real end: modelData.end
                  readonly property bool sung: sty.now >= w.t
                  // Up as it is sung, back down once the next word has it.
                  readonly property real lift: Kinetic.spring(sty.now - w.t, 22, 0.7) * (1 - Kinetic.smooth(end, end + 0.35, sty.now))

                  width: dim.implicitWidth
                  height: sty.rowH
                  y: -1.1 * sty.u * lift

                  LyricText {
                    id: dim

                    visible: word.fill < 1
                    text: word.w.text
                    size: sty.size
                    font.weight: Font.Bold
                    color: sty.ink
                    opacity: 0.22
                  }

                  // The bright copy, shown as far as the voice has got through the word.
                  Item {
                    visible: word.sung
                    width: word.fill < 1 ? dim.implicitWidth * word.fill : dim.implicitWidth + 2 * sty.u
                    height: dim.implicitHeight
                    clip: word.fill < 1

                    LyricText {
                      text: word.w.text
                      size: sty.size
                      font.weight: Font.Bold
                      color: sty.mix(sty.accent, sty.ink, (sty.now - word.end) / 0.5)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
