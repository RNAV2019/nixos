import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// A terminal taking dictation. The line is typed in a monospace face, a word's letters landing
// one after another across the time it is sung, with a block caret riding the last of them and
// blinking while the voice rests. The word under the caret is in the cover's colour. When the
// next line comes the log scrolls up a line, and what was typed dims and is gone after two.
LyricStyle {
  id: sty

  bloom: 0.3
  bloomKick: 0.15
  aberration: 0.001
  aberrationKick: 0.002
  glitchKick: 0.16
  scan: 0.4
  grain: 0.07
  vignette: 0.5
  ground: 0.7

  readonly property real size: 6 * u
  readonly property real room: width * 0.7
  readonly property real inset: (width - room) / 2
  readonly property real rowH: size * 1.36
  readonly property real gap: rowH * 0.55
  readonly property int maxRows: 4
  // Where the line in hand begins, from the top.
  readonly property real home: height * 0.5 - rowH * 0.5

  FontMetrics {
    id: metrics

    font.family: Theme.lyricMonoFont
    font.pixelSize: Math.max(1, Math.round(sty.size))
  }

  readonly property real cw: Math.max(1, metrics.advanceWidth("M"))

  // A line broken into rows of whole words (a word longer than a row is broken where it must),
  // narrower type when it would take more than four rows. Every word knows its row and column,
  // which is all a monospace face needs to place it.
  function layout(i) {
    if (i < 0 || i >= lines.length)
      return null;
    var words = lines[i].words;
    var k = 1;
    var out;
    do {
      var cols = Math.max(4, Math.floor(room * k / cw));
      var rows = [""];
      var placed = [];
      words.forEach(function (w) {
        var text = String(w.text);
        var r = rows.length - 1;
        var need = (rows[r].length > 0 ? 1 : 0) + text.length;
        if (rows[r].length > 0 && rows[r].length + need > cols) {
          rows.push("");
          r++;
        } else if (rows[r].length > 0) {
          rows[r] += " ";
        }
        // A word wider than a row is carried on in the next.
        var col = rows[r].length;
        var startRow = r;
        rows[r] += text;
        while (rows[r].length > cols) {
          rows.push(rows[r].substring(cols));
          rows[r] = rows[r].substring(0, cols);
          r++;
        }
        placed.push({
          row: startRow,
          col: col,
          len: text.length,
          text: text
        });
      });
      out = {
        rows: rows,
        words: placed,
        scale: 1 / k,
        h: rows.length * sty.rowH / k
      };
      k *= 1.15;
    } while (out.rows.length > maxRows && k < 4)
    return out;
  }

  // The line in hand and the three before it, laid out once each time the line changes.
  readonly property var lays: {
    var m = {};
    if (cur < 0)
      return m;
    for (var i = Math.max(first, cur - 3); i <= cur; i++)
      m[i] = layout(i);
    return m;
  }
  // The log scrolling up as a line comes in.
  readonly property real scroll: line ? Kinetic.spring(now - (line.t - lead), 15, 1) : 1
  readonly property real lift: cur > first && lays[cur - 1] ? (1 - scroll) * (lays[cur - 1].h + gap) : 0
  // Everything goes once the line in hand has had its time and nothing follows it.
  readonly property real leaving: line ? 1 - Kinetic.span(line.out - 0.25, line.out + 0.15, now) : 0

  // How many of a word's letters are down.
  function typed(w) {
    if (now < w.t)
      return 0;
    var n = String(w.text).length;
    return Math.min(n, 1 + Math.floor((n - 1) * (now - w.t) / Math.max(0.06, w.d * 0.8)));
  }

  Repeater {
    model: 5

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 5)
      readonly property bool here: lineIndex >= 0 && lineIndex <= sty.cur && lineIndex >= sty.cur - 3
      readonly property var lay: here ? sty.lays[lineIndex] : null
      readonly property var line: here ? sty.lines[lineIndex] : null
      // Lines between this one and the one in hand, less the part of the scroll still to come.
      readonly property real depth: (sty.cur - lineIndex) - (sty.cur > sty.first ? 1 - sty.scroll : 0)
      readonly property real place: {
        var y = sty.home + sty.lift;
        for (var i = sty.cur - 1; i >= lineIndex; i--)
          y -= (sty.lays[i] ? sty.lays[i].h : 0) + sty.gap;
        return y;
      }
      // The latest word begun, how far it is typed, and whether it is still being typed.
      readonly property int at: {
        if (!line)
          return -1;
        var j = -1;
        for (var k = 0; k < line.words.length; k++)
          if (line.words[k].t <= sty.now)
            j = k;
        return j;
      }
      // Its place in the layout; null for a moment while the slot changes line.
      readonly property var atWord: lay && at >= 0 && at < lay.words.length ? lay.words[at] : null
      readonly property int atTyped: at >= 0 ? sty.typed(line.words[at]) : 0
      readonly property bool typing: at >= 0 && sty.now < line.words[at].t + line.words[at].d + 0.1

      x: sty.inset
      y: place
      width: sty.room
      scale: lay ? lay.scale : 1
      transformOrigin: Item.TopLeft
      // The line in hand shows its prompt and caret from its lead, before a letter is down.
      visible: lay !== null && (at >= 0 || lineIndex === sty.cur) && opacity > 0.002
      opacity: (depth <= 0 ? 1 : depth <= 1 ? Kinetic.lerp(1, 0.4, depth) : depth <= 2 ? Kinetic.lerp(0.4, 0.17, depth - 1) : Kinetic.lerp(0.17, 0, depth - 2)) * sty.leaving

      // The prompt, hung in the margin of the line's first row.
      LyricText {
        x: -2 * sty.cw
        text: "›"
        font.family: Theme.lyricMonoFont
        font.weight: Font.Normal
        size: sty.size
        color: sty.accent
        opacity: Kinetic.clamp01(1 - slot.depth)
      }

      Repeater {
        model: slot.lay ? slot.lay.rows : []

        Item {
          id: row

          required property string modelData
          required property int index

          readonly property var active: slot.typing ? slot.atWord : null
          // How much of this row is typed and settled in ink.
          readonly property int done: {
            if (slot.at < 0)
              return 0;
            var w = slot.atWord;
            if (!w)
              return 0;
            if (w.row > index)
              return modelData.length;
            if (w.row < index)
              return 0;
            return slot.typing ? w.col : w.col + slot.atTyped;
          }

          y: index * sty.rowH

          LyricText {
            text: row.modelData.substring(0, row.done)
            font.family: Theme.lyricMonoFont
            font.weight: Font.Normal
            size: sty.size
            color: sty.ink
          }

          LyricText {
            visible: row.active !== null && row.active.row === row.index
            x: row.active ? row.active.col * sty.cw : 0
            text: row.active ? row.active.text.substring(0, slot.atTyped) : ""
            font.family: Theme.lyricMonoFont
            font.weight: Font.Bold
            size: sty.size
            color: sty.accent
          }
        }
      }

      // The caret, after the last letter typed; between words it blinks on the wall's clock.
      Rectangle {
        readonly property var w: slot.atWord
        readonly property int pos: w ? w.col + slot.atTyped : 0
        readonly property int cols: Math.floor(sty.room / slot.scale / sty.cw)

        visible: slot.lineIndex === sty.cur && (slot.typing || Math.floor(sty.stage.wall * 2.4) % 2 === 0)
        x: (pos >= cols ? cols - 1 : pos) * sty.cw + 0.12 * sty.cw
        y: (w ? w.row : 0) * sty.rowH + sty.rowH * 0.2
        width: sty.cw * 0.78
        height: sty.rowH * 0.66
        color: slot.typing ? sty.accent : sty.ink
        opacity: 0.85
      }
    }
  }
}
