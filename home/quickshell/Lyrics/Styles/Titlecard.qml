import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The line as a silent film's title card: a centred stack of soft, heavy capitals. A word's
// letters turn up out of order, grey at first and then lit, blink out now and then as a worn
// print's do, and at the end go dark one by one.
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
        readonly property real fit: Math.min(1, sty.height * 0.7 / Math.max(1, implicitHeight))

        x: (slot.width - width) / 2
        y: slot.height * 0.47 - height / 2
        scale: fit * (1 + 0.04 * slot.push)

        Repeater {
          model: slot.rows

          Item {
            id: band

            required property var modelData

            readonly property real fit: Math.min(1, sty.width * 0.7 / Math.max(1, strip.implicitWidth))

            anchors.horizontalCenter: parent.horizontalCenter
            width: strip.implicitWidth * fit
            // The rows sit close: capitals have nothing below the line to make room for.
            height: strip.implicitHeight * fit * 0.84

            Row {
              id: strip

              spacing: 3.2 * sty.u
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
                  size: 13 * sty.u
                  color: w ? sty.mix(sty.unlit, sty.ink, (sty.now - w.t - span) / 0.25) : sty.ink
                  now: sty.now
                  born: w ? w.t : 0
                  span: w ? Math.min(w.d * 0.7, 0.3) : 0
                  rise: 0.1
                  scattered: true
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
