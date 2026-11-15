import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// One word at a time, and it owns the screen. Two faces share the work: the passing words in a
// heavy grotesque's capitals, and the ones the singer leans on (a held note, the end of a line)
// in a fat serif's italic, larger. A word settles into place from a little too big or a little
// too low, swells for as long as it is held, and has cleared the stage before the next one
// lands. The line it belongs to runs small underneath, filling in as it is sung, so the eye can
// keep its place.
LyricStyle {
  id: sty

  bloom: 0.5
  bloomKick: 0.35
  punchKick: 0.15
  grain: 0.06
  vignette: 0.45
  ground: 1.15

  // How long before the next word a word starts to go, so the two are never up together.
  readonly property real clear: 0.11

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? (sty.lines[lineIndex] || null) : null
      // How long this line's words run, one with another.
      readonly property real usual: line ? (line.end - line.t) / line.words.length : 1

      anchors.fill: parent

      Repeater {
        model: slot.line ? slot.line.words : []

        Item {
          id: hit

          required property var modelData
          required property int index

          readonly property real age: sty.now - modelData.t
          readonly property real until: slot.line ? sty.until(slot.line, index) : 0
          // The singer leans on it: it is held half as long again as the line's words are, or
          // it ends the line.
          readonly property bool loud: modelData.d > 1.5 * slot.usual || (slot.line !== null && index === slot.line.words.length - 1)
          readonly property real land: Kinetic.spring(age, 22, 1)
          readonly property real held: Kinetic.span(modelData.t, until, sty.now)
          readonly property real leave: Kinetic.span(until - sty.clear, until - 0.01, sty.now)

          anchors.fill: parent
          visible: age > 0 && sty.now < until
          opacity: Kinetic.clamp01(age / 0.06) * (1 - leave)

          LyricText {
            id: word

            // Fitted once: as wide as the stage lets it be, as tall as its kind may be.
            readonly property real fit: Math.min(sty.width * 0.8 / Math.max(1, implicitWidth), (hit.loud ? 42 : 28) * sty.u / Math.max(1, implicitHeight))

            x: (hit.width - width) / 2
            y: hit.height * 0.45 - height / 2 + (hit.loud ? 0 : (1 - hit.land) * 5 * sty.u) - hit.leave * 4 * sty.u
            text: Kinetic.bare(hit.modelData.text)
            caps: !hit.loud
            font.family: hit.loud ? Theme.lyricFatSerifFont : Theme.lyricGroteskFont
            font.weight: Font.Normal
            font.italic: hit.loud
            size: 20 * sty.u
            color: sty.ink
            scale: fit * (hit.loud ? 1.3 - 0.3 * hit.land : 1) * (1 + 0.05 * hit.held)
          }
        }
      }

      // The line, small, under the word.
      Row {
        readonly property real up: slot.line ? Kinetic.span(slot.line.t - sty.lead, slot.line.t, sty.now) * (1 - Kinetic.span(slot.line.out - 0.2, slot.line.out, sty.now)) : 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.8
        spacing: 1.1 * sty.u
        opacity: up
        visible: up > 0

        Repeater {
          model: slot.line ? slot.line.words : []

          LyricText {
            required property var modelData

            text: modelData.text
            caps: false
            font.weight: Font.Medium
            size: 3.4 * sty.u
            color: sty.ink
            opacity: 0.35 + 0.65 * Kinetic.span(modelData.t, modelData.t + 0.12, sty.now)
          }
        }
      }
    }
  }
}
