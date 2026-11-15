import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// One word at a time, and it owns the screen. Each lands a different way and in a different
// face (slammed in from too large, thrown up from below, dropped, swung in), swells for as long
// as it is held, and is knocked out by the next. The line it belongs to runs small underneath,
// filling in as it is sung, so the eye can keep its place.
LyricStyle {
  id: sty

  bloom: 0.55
  bloomKick: 0.55
  aberration: 0.0015
  aberrationKick: 0.007
  punchKick: 0.6
  shakeKick: 0.5
  flashKick: 0.035
  grain: 0.06
  vignette: 0.45
  ground: 1.2

  // How long a word takes to leave once the next has landed.
  readonly property real exit: 0.15

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null

      anchors.fill: parent

      Repeater {
        model: slot.line ? slot.line.words : []

        Item {
          id: hit

          required property var modelData
          required property int index

          readonly property real age: sty.now - modelData.t
          readonly property real until: sty.until(slot.line, index)
          readonly property real gone: sty.now - until
          // Which way it comes in, and whether it is one of the line's loud ones.
          readonly property int way: Math.floor(Kinetic.hash(sty.seed, slot.lineIndex, index) * 4)
          readonly property bool loud: modelData.d > 0.45 || index === slot.line.words.length - 1
          readonly property real land: Kinetic.spring(age, 30, 0.58)
          readonly property real held: Kinetic.clamp01(age / Math.max(0.3, until - modelData.t))
          readonly property real leave: Kinetic.outCubic(gone / sty.exit)

          anchors.fill: parent
          visible: age > -0.02 && gone < sty.exit
          opacity: Kinetic.clamp01(age / 0.05) * (1 - leave)

          LyricText {
            id: word

            // Fitted once: as wide as the stage lets it be, as tall as a loud word may be.
            readonly property real fit: Math.min(sty.width * 0.84 / Math.max(1, implicitWidth), (hit.loud ? 46 : 34) * sty.u / Math.max(1, implicitHeight))

            x: (hit.width - width) / 2 + (hit.way === 3 ? (1 - hit.land) * -30 * sty.u : 0)
            y: (hit.height * 0.46 - height / 2) + (hit.way === 1 ? (1 - hit.land) * 26 * sty.u : hit.way === 2 ? (1 - hit.land) * -26 * sty.u : 0) - hit.leave * 16 * sty.u
            text: Kinetic.bare(hit.modelData.text)
            face: sty.face(slot.lineIndex, hit.index)
            size: 20 * sty.u
            color: hit.loud ? sty.accent : sty.ink
            scale: fit * (hit.way === 0 ? 2.1 - 1.1 * hit.land : 1) * (1 + 0.09 * hit.held) * (1 - 0.3 * hit.leave)
            rotation: (hit.way === 1 ? 6 : hit.way === 3 ? -5 : 0) * (1 - hit.land) + Kinetic.jitter(sty.seed, slot.lineIndex, hit.index + 40) * 2.5
          }
        }
      }

      // The line, small, under the word.
      Row {
        readonly property real up: slot.line ? Kinetic.span(slot.line.t - sty.lead, slot.line.t, sty.now) * (1 - Kinetic.span(slot.line.out, slot.line.out + 0.25, sty.now)) : 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.8
        spacing: 0.9 * sty.u
        opacity: up
        visible: up > 0

        Repeater {
          model: slot.line ? slot.line.words : []

          LyricText {
            required property var modelData

            text: modelData.text
            font.family: Theme.uiFont
            font.weight: Theme.weightMedium
            size: 2.6 * sty.u
            color: sty.ink
            opacity: 0.3 + 0.7 * Kinetic.span(modelData.t, modelData.t + 0.12, sty.now)
          }
        }
      }
    }
  }
}
