import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The line as a silent film's title card: a centred stack of soft, heavy capitals. A word
// comes up grey and is then lit, a row falls back to grey when the next begins, letters blink
// out now and then as a worn print's do, and at the end they go dark one by one, in no order.
FilmStyle {
  id: sty

  bloomKick: 0.2

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? (sty.lines[lineIndex] || null) : null
      readonly property var rows: line ? Kinetic.rows(line.words) : []
      readonly property real push: line ? Kinetic.span(line.t, line.out, sty.now) : 0

      anchors.fill: parent
      visible: line !== null && sty.now > line.t - 0.05 && sty.now < line.out

      Column {
        id: stack

        // A card of four rows is drawn smaller, whole.
        readonly property real fit: Math.min(1, sty.height * 0.72 / Math.max(1, implicitHeight))

        x: (slot.width - width) / 2
        y: slot.height * 0.47 - height / 2
        scale: fit * (1 + 0.04 * slot.push)

        Repeater {
          model: slot.rows

          Item {
            id: band

            required property var modelData

            readonly property real fit: Math.min(1, sty.width * 0.76 / Math.max(1, strip.implicitWidth))
            // The word the next row opens with, when there is a next row, and how far this row
            // has fallen back since it began.
            readonly property int after: modelData[modelData.length - 1] + 1
            readonly property real spent: slot.line && after < slot.line.words.length ? Kinetic.smooth(slot.line.words[after].t, slot.line.words[after].t + 0.5, sty.now) : 0

            anchors.horizontalCenter: parent.horizontalCenter
            width: strip.implicitWidth * fit
            // The rows sit close: capitals have nothing below the line to make room for.
            height: strip.implicitHeight * fit * 0.8
            opacity: 1 - 0.42 * spent

            Row {
              id: strip

              spacing: 4 * sty.u
              scale: band.fit
              transformOrigin: Item.TopLeft

              Repeater {
                model: band.modelData

                LyricLetters {
                  required property int modelData

                  readonly property var w: slot.line && modelData < slot.line.words.length ? slot.line.words[modelData] : null

                  text: w ? Kinetic.bare(w.text) : ""
                  caps: true
                  family: Theme.lyricCardFont
                  size: 18 * sty.u
                  color: w ? sty.mix(sty.unlit, sty.ink, (sty.now - w.t - span) / 0.25) : sty.ink
                  now: sty.now
                  born: w ? w.t : 0
                  span: w ? Math.min(w.d * 0.4, 0.12) : 0
                  rise: 0.1
                  flicker: sty.blink
                  gone: slot.line ? slot.line.out - 0.45 : Infinity
                  seed: sty.seed
                  salt: slot.lineIndex * 40 + modelData
                }
              }
            }
          }
        }
      }
    }
  }
}
