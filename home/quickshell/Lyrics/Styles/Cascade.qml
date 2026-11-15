import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// A tower of words. Each word drops in from above, one under the last, lands with a bounce and
// a squash, and settles a little crooked, so the line stacks into a leaning column left of
// centre that reads top to bottom. Condensed capitals take turns with a light italic, and a
// word held long is set large. When the next line comes the tower gives way: every piece falls
// under gravity, each with its own spin, as the new line's first word drops in above it.
LyricStyle {
  id: sty

  bloom: 0.42
  bloomKick: 0.3
  aberration: 0.001
  aberrationKick: 0.004
  punchKick: 0.3
  shakeKick: 0.35
  grain: 0.05
  vignette: 0.45
  ground: 0.9

  // The two faces the tower alternates between, as Theme.lyricFaces sets them out.
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
  // How long a word takes to fall into place, and how far above it it starts.
  readonly property real drop: 0.2
  readonly property real dropHeight: 15 * u
  readonly property real dropSlide: 12 * u
  // The tower's collapse, as the next line comes into hand.
  readonly property real gravity: 520 * u

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      readonly property real fallen: line ? sty.now - (line.out - sty.lead) : -1
      // Which face the line starts on.
      readonly property int foot: Math.floor(Kinetic.hash(sty.seed, lineIndex) * 2)
      // Every landing rocks the tower a little; the rocks ring out.
      readonly property real sway: {
        if (!line)
          return 0;
        var s = 0;
        for (var j = 0; j < line.words.length; j++) {
          var a = sty.now - line.words[j].t - sty.drop;
          if (a > 0 && a < 1.5)
            s += (j % 2 === 0 ? 1 : -1) * 1.4 * Math.exp(-4 * a) * Math.sin(10 * a);
        }
        return s;
      }

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
        rotation: slot.sway * (1 - Kinetic.span(0, 0.2, slot.fallen))

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
            readonly property real rest: (index % 2 === 0 ? 1 : -1) * (2 + 3 * Kinetic.hash(sty.seed + 3, slot.lineIndex, index))
            // The collapse: the bottom of the tower goes first.
            readonly property real tau: Math.max(0, slot.fallen - (slot.line.words.length - 1 - index) * 0.035)
            readonly property real spin: Kinetic.jitter(sty.seed + 17, slot.lineIndex, index) * 160

            x: Kinetic.jitter(sty.seed + 5, slot.lineIndex, index) * 3 * sty.u
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
              visible: brick.age > 0 && brick.tau < 1.2
              // Faint while it falls past the words above it, solid as it lands.
              opacity: Kinetic.span(0.4, 0.95, brick.fall) * (1 - Kinetic.span(0.45, 0.9, brick.tau))
              scale: brick.k
              rotation: brick.rest + (1 - Kinetic.outCubic(brick.fall)) * brick.rest * 4 + (brick.since > 0 ? 3 * Math.exp(-5 * brick.since) * Math.sin(18 * brick.since) : 0) + brick.spin * brick.tau
              transform: [
                // The squash on landing, from its foot.
                Scale {
                  origin.x: word.width / 2
                  origin.y: word.height * 0.8
                  xScale: brick.since > 0 ? 1 + 0.16 * Math.exp(-11 * brick.since) * Math.cos(22 * brick.since) : 1
                  yScale: brick.since > 0 ? 1 - 0.22 * Math.exp(-11 * brick.since) * Math.cos(22 * brick.since) : 1.12
                },
                Translate {
                  // Falling in under gravity, then bouncing on the pile; then the collapse.
                  y: (brick.fall < 1 ? -sty.dropHeight * (1 - brick.fall * brick.fall) : -2.4 * sty.u * Math.exp(-6 * brick.since) * Math.abs(Math.sin(15 * brick.since))) + 0.5 * sty.gravity * brick.tau * brick.tau
                  // It comes in from up and to the right, so it slides past the words above it
                  // rather than through them.
                  x: (1 - brick.fall) * sty.dropSlide + Kinetic.jitter(sty.seed + 23, slot.lineIndex, brick.index) * 30 * sty.u * brick.tau
                }
              ]
            }
          }
        }
      }
    }
  }
}
