import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Words and their pictures. The line is set large and plain in centred rows, each word popping
// up as it is sung; a word with an obvious picture (fire, moon, sky, road...) is set in the
// cover's colour and its emoji springs in beside it with a wobble, throwing off a handful of
// small copies of itself that burst outward and fall away. The rest of the line stays quiet so
// the pictures are the event.
LyricStyle {
  id: sty

  bloom: 0.5
  bloomKick: 0.35
  aberration: 0.0012
  aberrationKick: 0.004
  punchKick: 0.2
  shakeKick: 0.1
  grain: 0.05
  vignette: 0.4
  ground: 1

  // How many small copies a picture throws off, and how long they fly.
  readonly property int sparks: 8
  readonly property real flight: 1.3
  // Pictures that are signs rather than things: they say nothing beside a word, so the word
  // goes without.
  readonly property var signs: ["⬆️", "⬇️", "🚫", "♾️", "💯", "1️⃣", "2️⃣", "3️⃣", "🗣️", "🤝"]

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      // The line lifts away as the next comes into hand, and is gone by the time its first word
      // is sung in the same place.
      readonly property real leave: line ? Kinetic.span(line.out - sty.lead, line.out - 0.02, sty.now) : 0

      anchors.fill: parent
      visible: line !== null && sty.now > line.t - sty.lead && leave < 1

      Column {
        id: block

        // The whole line fitted once to the stage; the pictures make a row wider, so they are
        // in the measure from the start and nothing reflows as they arrive.
        readonly property real fit: Math.min(1.3, sty.width * 0.84 / Math.max(1, width), sty.height * 0.66 / Math.max(1, height))

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -slot.leave * 6 * sty.u
        spacing: 0.8 * sty.u
        scale: fit * (1 - 0.06 * slot.leave)
        opacity: 1 - Kinetic.inCubic(slot.leave)

        Repeater {
          model: slot.line ? Kinetic.rows(slot.line.words) : []

          Row {
            id: row

            required property var modelData

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2.4 * sty.u

            Repeater {
              model: row.modelData

              Item {
                id: cell

                required property int modelData

                readonly property var word: slot.line.words[modelData]
                readonly property bool pictured: word.emoji !== "" && sty.signs.indexOf(word.emoji) < 0
                readonly property real age: sty.now - word.t
                readonly property real pop: Kinetic.spring(age, 26, 0.55)
                // The picture follows the word by a beat.
                readonly property real pAge: age - 0.06
                readonly property real picPop: Kinetic.spring(pAge, 17, 0.32)
                // The picture's square, beside the word, as tall as the word's capitals and a bit.
                readonly property real box: pictured ? said.implicitHeight * 0.8 : 0

                width: said.implicitWidth + (pictured ? box + 1.2 * sty.u : 0)
                height: said.implicitHeight * 0.92

                LyricText {
                  id: said

                  y: -said.implicitHeight * 0.04 + (1 - cell.pop) * 3 * sty.u
                  text: cell.word.text
                  size: 10 * sty.u
                  caps: false
                  color: cell.pictured ? sty.accent : sty.ink
                  visible: cell.age > -0.01
                  opacity: Kinetic.clamp01(cell.age / 0.06)
                  scale: 0.7 + 0.3 * cell.pop
                }

                LyricEmoji {
                  id: pic

                  // Sitting in its square, with a slow bob on the wall's clock once it is in.
                  x: said.implicitWidth + 1.2 * sty.u + (cell.box - width) / 2
                  y: (cell.height - height) / 2 + Math.sin(sty.stage.wall * 2.1 + cell.modelData) * 0.5 * sty.u * cell.picPop
                  glyph: cell.word.emoji
                  size: 120
                  visible: cell.pictured && cell.pAge > 0
                  scale: cell.box / Math.max(1, implicitHeight) * 1.08 * cell.picPop
                  // A wobble that rings out.
                  rotation: 28 * Math.exp(-4.5 * cell.pAge) * Math.sin(19 * cell.pAge) + Kinetic.jitter(sty.seed, slot.lineIndex, cell.modelData) * 6
                }

                // The burst: small copies flung out from the picture on ballistic paths, each a
                // pure function of the picture's age.
                Repeater {
                  model: cell.pictured ? sty.sparks : 0

                  LyricEmoji {
                    id: spark

                    required property int index

                    readonly property real h: Kinetic.hash(sty.seed + 101, slot.lineIndex * 16 + cell.modelData, index)
                    readonly property real a: cell.pAge
                    // Spread round the circle but flattened, so they fly out sideways past the line rather than
                    // up through the row above, and only hop a little before they fall.
                    readonly property real theta: (index / sty.sparks) * 2 * Math.PI + Kinetic.jitter(sty.seed + 7, cell.modelData, index) * 0.35
                    readonly property real speed: (34 + 30 * h) * sty.u
                    readonly property real vx: Math.cos(theta) * speed
                    readonly property real vy: Math.sin(theta) * speed * 0.45 - 12 * sty.u
                    readonly property real size0: 0.28 + 0.2 * h

                    x: pic.x + (pic.width - width) / 2 + vx * a
                    y: pic.y + (pic.height - height) / 2 + vy * a + 0.5 * 110 * sty.u * a * a
                    glyph: cell.word.emoji
                    size: 120
                    visible: a > 0 && a < sty.flight
                    opacity: Kinetic.clamp01(a / 0.05) * (1 - Kinetic.span(sty.flight * 0.5, sty.flight, a))
                    scale: cell.box / Math.max(1, implicitHeight) * size0 * (0.6 + 0.4 * Kinetic.outCubic(a / 0.12)) * (1 - 0.4 * a / sty.flight)
                    rotation: Kinetic.jitter(sty.seed + 13, cell.modelData, index) * 400 * a
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
