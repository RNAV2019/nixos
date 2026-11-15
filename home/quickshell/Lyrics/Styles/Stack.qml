import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The lyrics view every player has converged on, and the plainest thing the stage does: the
// song's lines in a column, left-aligned in bold, the one in hand at a fixed height and the
// column springing past it as the song goes. A line waits dim and fills in from the left as it
// is sung, a letter after a letter, so the edge of the fill is soft; the word being sung lifts
// a twentieth of its height and a long note swells a little. The lines round the one in hand
// are dimmer, a touch smaller, and out of focus by how far off they are, which is the lens's
// doing (`depth`): nothing here is blurred item by item. Alone among the styles it shows lines
// that are not its segment's, a couple before and a few after, since a column that began and
// ended with its own two or three lines would be most of it empty.
LyricStyle {
  id: sty

  bloom: 0.4
  bloomKick: 0.1
  grain: 0.04
  vignette: 0.45
  ground: 1.05

  // Where the line in hand begins, the column's inset and width, the type and the gap
  // between lines.
  readonly property real anchor: 0.36 * height
  readonly property real inset: 0.11 * width
  readonly property real room: 0.74 * width
  readonly property real size: 8 * u
  readonly property real gap: 3 * u
  // What a letter shows before it is sung, and a line that is not the one in hand.
  readonly property real waiting: 0.42
  readonly property real passed: 0.3
  readonly property real ahead: 0.55
  readonly property real small: 0.965

  // The column: the segment's lines, two before them and three after, where the song has them.
  readonly property int head: first < 0 ? 0 : Math.max(0, first - 2)
  readonly property int count: first < 0 ? 0 : Math.min(lines.length - 1, last + 3) - head + 1
  // The line in hand as the column counts them; the segment's first, until that is due.
  readonly property int at: Math.max(first, cur) - head
  // Each line's distance down the column. (`itemAt` is not watched, so the count is read too.)
  readonly property var tops: {
    var out = [];
    var y = 0;
    for (var i = 0; i < column.count; i++) {
      out.push(y);
      var row = column.itemAt(i);
      y += (row ? row.height : sty.size) + sty.gap;
    }
    return out;
  }
  readonly property real inHand: column.count > at && column.itemAt(at) ? column.itemAt(at).height : size
  // How far the column has come from the line before to the line in hand.
  function moved(late) {
    return line ? Kinetic.spring(now - (line.t - lead) - late, 13.5, 1) : 1;
  }

  depth: count > 0 ? 1 : 0
  depthAt: (anchor + inHand / 2) / Math.max(1, height)
  depthBand: (inHand / 2 + 1.5 * u) / Math.max(1, height)

  Repeater {
    id: column

    model: sty.count

    Flow {
      id: row

      required property int index

      readonly property var line: sty.lines[sty.head + index] || null
      // Lines from the one in hand: negative for those sung.
      readonly property int away: index - sty.at
      readonly property bool current: sty.cur === sty.head + index
      // Each line below the one in hand follows a twentieth of a second behind the last.
      readonly property real moved: sty.moved(Math.max(0, away) * 0.05)
      readonly property real from: sty.at > 0 && sty.at - 1 < sty.tops.length ? sty.tops[sty.at - 1] : 0
      readonly property real to: sty.at < sty.tops.length ? sty.tops[sty.at] : 0
      // 1 while it is the line in hand, coming up to it and falling away from it with the scroll.
      readonly property real lit: current ? sty.moved(0) : away === -1 ? 1 - sty.moved(0) : 0

      x: sty.inset
      y: sty.anchor + (index < sty.tops.length ? sty.tops[index] : 0) - Kinetic.lerp(from, to, moved)
      width: sty.room
      spacing: 0.26 * sty.size
      transformOrigin: Item.Left
      scale: Kinetic.lerp(sty.small, 1, lit)
      opacity: Kinetic.lerp(away < 0 ? sty.passed : sty.ahead, 1, lit)
      visible: y + height > 0 && y < sty.height

      Repeater {
        model: row.line ? row.line.words : []

        LyricLetters {
          id: word

          required property var modelData
          required property int index

          // A note held a second or more swells as it is held.
          readonly property real held: modelData.d >= 1 ? Math.sin(Math.PI * Kinetic.span(modelData.t, modelData.t + modelData.d, sty.now)) : 0

          text: modelData.text
          family: Theme.lyricDisplayFont
          weight: Font.Bold
          size: sty.size
          color: sty.ink
          now: sty.now
          born: modelData.t
          span: modelData.d * 0.7
          rise: Math.max(0.1, modelData.d * 0.35)
          floor: sty.waiting
          transformOrigin: Item.Left
          scale: 1 + 0.045 * held
          transform: Translate {
            y: -0.05 * sty.size * Kinetic.smooth(word.modelData.t, word.modelData.t + Math.max(0.3, word.modelData.d), sty.now) * row.lit
          }
        }
      }
    }
  }
}
