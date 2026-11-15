import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// A column of words. Each word comes up into place under the last, so the line stacks into a
// column left of centre that reads top to bottom. Condensed capitals take turns with a light
// italic, and a word held long is set large. When the next line comes the column lets go and
// sinks away as the new line's first word arrives above it.
LyricStyle {
  id: sty

  bloom: 0.42
  bloomKick: 0.2
  grain: 0.05
  vignette: 0.45
  ground: 0.9

  // The two faces the column alternates between, as LyricText takes them.
  readonly property var capitals: ({
      family: Theme.lyricCondensedFont,
      weight: Font.Normal,
      italic: false,
      caps: true,
      size: 1.14
    })
  readonly property var italic: ({
      family: Theme.lyricSerifFont,
      weight: Font.Normal,
      italic: true,
      caps: false,
      size: 1.22
    })
  // How long a word takes to come up into place, and how far below it it starts: from below,
  // so it never crosses the word above it.
  readonly property real drop: 0.26
  readonly property real dropHeight: 5 * u

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      readonly property real fallen: line ? sty.now - (line.out - 0.16) : -1
      // Which face the line starts on.
      readonly property int foot: Math.floor(Kinetic.hash(sty.seed, lineIndex) * 2)
      // How much of the tower has come down so far, eased in behind each landing: the tower is
      // kept centred on what is there, so it climbs as it grows and a new word lands near the
      // middle of the stage rather than at the foot of an empty column.
      readonly property real built: {
        if (!line)
          return 0;
        // itemAt is not watched: reading the count makes this run again once the bricks exist,
        // which matters when the song is paused and `now` stands still.
        var n = bricks.count;
        var h = 0;
        for (var j = 0; j < n; j++) {
          var b = bricks.itemAt(j);
          if (b)
            h += b.height * Kinetic.spring(sty.now - line.words[j].t - sty.drop * 0.5, 11, 0.9);
        }
        return h;
      }

      anchors.fill: parent
      visible: line !== null && sty.now > line.t - sty.lead && fallen < 1.3

      Column {
        id: tower

        // Fitted once, whole, so a long line is a smaller tower rather than a taller one.
        readonly property real fit: Math.min(1, sty.height * 0.82 / Math.max(1, height), sty.width * 0.62 / Math.max(1, width))

        x: sty.width * 0.27
        y: (sty.height - slot.built * fit) / 2
        scale: fit
        transformOrigin: Item.TopLeft

        Repeater {
          id: bricks

          model: slot.line ? slot.line.words : []

          Item {
            id: brick

            required property var modelData
            required property int index

            readonly property bool caps: (index + slot.foot) % 2 === 0
            // Long notes are set large.
            readonly property real k: (0.62 + 0.78 * Kinetic.span(0.3, 1.4, modelData.d)) * (caps ? 1 : 0.92)
            readonly property real age: sty.now - modelData.t
            readonly property real since: age - sty.drop
            readonly property real fall: Kinetic.clamp01(age / sty.drop)
            // Letting go: the foot of the column first.
            readonly property real tau: Math.max(0, slot.fallen - (slot.line.words.length - 1 - index) * 0.03)

            width: word.implicitWidth * k
            height: word.implicitHeight * k * (caps ? 0.8 : 0.66)

            LyricText {
              id: word

              x: (brick.width - width) / 2
              y: (brick.height - height) / 2 + (brick.caps ? 0 : -0.06 * height)
              text: Kinetic.bare(brick.modelData.text)
              face: brick.caps ? sty.capitals : sty.italic
              size: 12 * sty.u
              color: brick.caps ? sty.ink : sty.accent
              visible: brick.age > 0 && brick.tau < 0.4
              opacity: Kinetic.outCubic(brick.fall) * (1 - Kinetic.span(0, 0.35, brick.tau))
              scale: brick.k
              transform: Translate {
                // Up into place, and a little down again as it goes.
                y: sty.dropHeight * (1 - Kinetic.outCubic(brick.fall)) + 3 * sty.u * Kinetic.inCubic(brick.tau / 0.35)
              }
            }
          }
        }
      }
    }
  }
}
