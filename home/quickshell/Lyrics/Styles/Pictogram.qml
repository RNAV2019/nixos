import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The line set large in the middle of the stage, in rows, each word rising into place as it is
// sung; a word with an obvious picture (word.emoji) has it beside it, as tall as the word's
// capitals, arriving a beat after the word and then still. The pictures are in the line's
// measure from the start, so nothing shifts as they arrive.
LyricStyle {
  id: sty

  bloom: 0.5
  bloomKick: 0.2
  grain: 0.05
  vignette: 0.4
  ground: 1

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      // The line lifts away as the next comes into hand, and is gone by the time its first word
      // is sung in the same place.
      readonly property real leave: line ? Kinetic.span(line.out - 0.18, line.out - 0.02, sty.now) : 0

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
                readonly property bool pictured: word.emoji !== ""
                readonly property real age: sty.now - word.t
                readonly property real pop: Kinetic.outCubic(age / 0.22)
                // The picture follows the word by a beat.
                readonly property real pAge: age - 0.08
                // The picture's square, beside the word, as tall as the word's capitals and a bit.
                readonly property real box: pictured ? said.implicitHeight * 0.8 : 0

                width: said.implicitWidth + (pictured ? box + 1.2 * sty.u : 0)
                height: said.implicitHeight * 0.92

                LyricText {
                  id: said

                  y: -said.implicitHeight * 0.04 + (1 - cell.pop) * 1.2 * sty.u
                  text: cell.word.text
                  size: 10 * sty.u
                  caps: false
                  color: cell.pictured ? sty.accent : sty.ink
                  font.weight: Font.DemiBold
                  visible: cell.age > -0.01
                  opacity: cell.pop
                }

                LyricEmoji {
                  // In its square beside the word, as tall as the word's capitals, and still.
                  x: said.implicitWidth + 1.2 * sty.u + (cell.box - width) / 2
                  y: (cell.height - height) / 2
                  glyph: cell.word.emoji
                  size: 120
                  visible: cell.pictured && cell.pAge > 0
                  opacity: Kinetic.outCubic(cell.pAge / 0.3)
                  scale: cell.box / Math.max(1, implicitHeight) * (0.92 + 0.08 * Kinetic.outCubic(cell.pAge / 0.3))
                }
              }
            }
          }
        }
      }
    }
  }
}
