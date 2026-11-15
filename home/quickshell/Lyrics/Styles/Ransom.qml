import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// A ransom note. Every word is cut from a different page: its own face, its own scrap of paper
// (mostly white, some in the cover's colours, a few bare letters), set a little crooked and
// slapped down as it is sung. The line is laid out in ragged centred rows before it starts, so
// nothing shuffles as the note fills in; when the next line comes the scraps are swept off,
// each its own way, while the new note begins.
LyricStyle {
  id: sty

  bloom: 0.3
  bloomKick: 0.25
  aberration: 0.001
  aberrationKick: 0.004
  punchKick: 0.25
  shakeKick: 0.3
  grain: 0.09
  vignette: 0.5
  ground: 0.8

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      // The sweep begins as the next line comes into hand.
      readonly property real swept: line ? sty.now - (line.out - sty.lead) : -1

      anchors.fill: parent
      visible: line !== null && sty.now > line.t - sty.lead && swept < 1.4

      Column {
        id: note

        // The whole note fitted once to the stage, and pressed a little closer as it is read.
        readonly property real fit: Math.min(1.25, sty.width * 0.84 / Math.max(1, width), sty.height * 0.7 / Math.max(1, height))

        anchors.centerIn: parent
        spacing: 0.6 * sty.u
        scale: slot.line ? fit * (1 + 0.03 * Kinetic.span(slot.line.t, slot.line.out, sty.now)) : 1

        Repeater {
          model: slot.line ? Kinetic.rows(slot.line.words) : []

          Row {
            id: row

            required property var modelData
            required property int index

            anchors.horizontalCenter: parent.horizontalCenter
            // Rows are pasted a little off true, as a hand would.
            anchors.horizontalCenterOffset: Kinetic.jitter(sty.seed + 9, slot.lineIndex, index) * 2 * sty.u
            spacing: 0.7 * sty.u

            Repeater {
              model: row.modelData

              // One scrap: the item keeps the word's room in the row; all that moves is on
              // `card`.
              Item {
                id: plate

                // The word's index in its line (the rows deal out indices).
                required property int modelData

                readonly property int j: modelData
                readonly property var word: slot.line.words[j]
                readonly property real age: sty.now - word.t
                readonly property real h1: Kinetic.hash(sty.seed, slot.lineIndex, j)
                readonly property real h2: Kinetic.hash(sty.seed + 11, slot.lineIndex, j)
                readonly property real h3: Kinetic.hash(sty.seed + 23, slot.lineIndex, j)
                // Most scraps are white paper; some are cut from the cover's colours; a few are
                // no paper at all, just letters cut out of a black page.
                readonly property int paper: h1 < 0.58 ? 0 : h1 < 0.74 ? 1 : h1 < 0.88 ? 2 : 3
                // Cut-outs are never quite the same size.
                readonly property real k: 0.84 + 0.4 * h2
                readonly property real padX: (0.9 + 0.6 * h3) * sty.u
                readonly property real padY: (0.4 + 0.5 * h2) * sty.u
                readonly property real rest: Kinetic.jitter(sty.seed + 5, slot.lineIndex, j) * 5

                readonly property real land: Kinetic.spring(age, 24, 0.42)
                readonly property real slap: Kinetic.spring(age, 34, 0.75)

                // The sweep, each scrap on its own path: a shove sideways and up, then gravity,
                // a little later for some so the note peels off rather than going all at once.
                readonly property real tau: Math.max(0, slot.swept - 0.05 * j * h3)
                readonly property real vx: Kinetic.jitter(sty.seed + 31, slot.lineIndex, j) * 60 * sty.u
                readonly property real vy: -(10 + 25 * h1) * sty.u
                readonly property real spin: Kinetic.jitter(sty.seed + 37, slot.lineIndex, j) * 260

                width: cut.implicitWidth * k + 2 * padX
                height: 12.5 * sty.u

                Item {
                  id: card

                  width: plate.width
                  height: cut.implicitHeight * plate.k * 0.78 + 2 * plate.padY
                  y: (plate.height - height) / 2 + Kinetic.jitter(sty.seed + 3, slot.lineIndex, plate.j) * 0.8 * sty.u
                  visible: plate.age > 0 && plate.tau < 0.9
                  opacity: Kinetic.clamp01(plate.age / 0.04) * (1 - Kinetic.span(0.35, 0.9, plate.tau))
                  scale: 1 + 0.55 * (1 - plate.slap)
                  rotation: plate.rest + (1 - plate.land) * (plate.rest >= 0 ? -14 : 14) + plate.spin * plate.tau
                  transform: Translate {
                    x: plate.vx * plate.tau
                    y: plate.vy * plate.tau + 190 * sty.u * plate.tau * plate.tau
                  }

                  Rectangle {
                    anchors.fill: parent
                    visible: plate.paper < 3
                    radius: 0.5 * sty.u
                    color: plate.paper === 1 ? sty.accent : plate.paper === 2 ? sty.accent2 : sty.ink
                  }

                  LyricText {
                    id: cut

                    anchors.centerIn: parent
                    text: Kinetic.bare(plate.word.text)
                    face: sty.face(slot.lineIndex, plate.j)
                    size: 9 * sty.u
                    scale: plate.k
                    color: plate.paper < 3 ? "#000000" : sty.ink
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
