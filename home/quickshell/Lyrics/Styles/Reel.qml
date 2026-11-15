import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// A focus pull. The first half of the line comes up as a title, in fat capitals; as the second
// half begins the title goes out of focus and falls back, the projector's lamp swells behind,
// and the rest is written over it in script, a letter at a time. Letters blink out now and then
// as on a worn print, and at the end the script goes letter by letter. A line of three words or
// fewer is all title.
//
// In focus the title is drawn with everything else. Out of focus it is drawn on the stage's
// soft plate instead (`stage.softPlate`), which the lens blurs by `softRadius` and adds back as
// light: one blur for the whole stage, so the script over the title stays sharp.
FilmStyle {
  id: sty

  // The word the script begins at; the line's length when there is none.
  function split(line) {
    var n = line.words.length;
    return n >= 4 ? Math.ceil(n / 2) : n;
  }

  readonly property real scriptAt: line && split(line) < line.words.length ? line.words[split(line)].t : Infinity
  // How far out of focus the title of the line in hand is.
  readonly property real defocus: Kinetic.smooth(scriptAt - 0.1, scriptAt + 0.75, now)
  // The title's own measures.
  readonly property real titleSize: 13 * u
  readonly property real titleGap: 3.2 * u

  softens: true
  softRadius: 0.3 + 1.7 * defocus

  // The lamp comes up with the script, large and plain to see, and is down again before the
  // line goes.
  spot: line ? 0.56 * Kinetic.smooth(scriptAt - 0.3, scriptAt + 1.0, now) * (1 - Kinetic.span(line.out - 0.5, line.out - 0.05, now)) : 0
  spotSize: 0.4
  spotAt: Qt.point(0.47 + 0.03 * Math.sin(stage.wall * 0.21), 0.6 + 0.03 * Math.cos(stage.wall * 0.17))

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? (sty.lines[lineIndex] || null) : null
      readonly property int cut: line ? sty.split(line) : 0
      readonly property var titleWords: line ? line.words.slice(0, cut) : []
      readonly property var scriptWords: line ? line.words.slice(cut) : []
      readonly property real scriptAt: scriptWords.length > 0 ? scriptWords[0].t : Infinity
      // How far out of focus this line's title is.
      readonly property real soft: Kinetic.smooth(scriptAt - 0.1, scriptAt + 0.75, sty.now)
      readonly property real leaving: line ? Kinetic.span(line.out - 0.4, line.out - 0.05, sty.now) : 0
      readonly property real push: line ? Kinetic.span(line.t, line.out, sty.now) : 0
      readonly property bool up: line !== null && sty.now > line.t - 0.05 && sty.now < line.out
      // The title as wide as the stage lets it be, and where it then sits round the middle.
      readonly property real fit: Math.min(1, sty.width * 0.74 / Math.max(1, sharp.implicitWidth))
      readonly property real titleX: -sharp.implicitWidth * fit / 2
      readonly property real titleY: -sharp.implicitHeight * fit / 2 - soft * 1.2 * sty.u
      // The camera creeps in for as long as the line is held.
      readonly property real creep: 1 + 0.05 * push

      anchors.fill: parent
      visible: up

      Item {
        x: slot.width / 2
        y: slot.height * 0.46
        scale: slot.creep

        // The title in focus.
        Row {
          id: sharp

          x: slot.titleX
          y: slot.titleY
          spacing: sty.titleGap
          scale: slot.fit
          transformOrigin: Item.TopLeft
          // It hands over to its copy on the soft plate as the blur grows: the plate is drawn
          // small, and would show it before the blur was wide enough to hide it.
          opacity: 1 - Kinetic.span(0.05, 0.35, slot.soft)
          visible: slot.soft < 0.35

          Repeater {
            model: slot.titleWords

            LyricLetters {
              required property var modelData
              required property int index

              text: Kinetic.bare(modelData.text)
              caps: true
              family: Theme.lyricDidoneFont
              size: sty.titleSize
              color: sty.mix(sty.unlit, sty.ink, (sty.now - modelData.t - 0.08) / 0.3)
              now: sty.now
              born: modelData.t
              span: Math.min(modelData.d * 0.5, 0.14)
              rise: 0.14
              flicker: sty.blink
              gone: slot.scriptWords.length > 0 || !slot.line ? Infinity : slot.line.out - 0.45
              seed: sty.seed
              salt: slot.lineIndex * 40 + index
            }
          }
        }

        // The script, over the lower half of the title.
        Row {
          id: script

          readonly property real fit: Math.min(1, sty.width * 0.62 / Math.max(1, implicitWidth))

          x: -implicitWidth * fit / 2 + 1.5 * sty.u
          y: -implicitHeight * fit / 2 + 4.6 * sty.u
          spacing: 2.6 * sty.u
          scale: fit
          transformOrigin: Item.TopLeft

          Repeater {
            model: slot.scriptWords

            LyricLetters {
              required property var modelData
              required property int index

              text: Kinetic.bare(modelData.text).toLowerCase()
              family: Theme.lyricScriptFont
              size: 16.5 * sty.u
              color: sty.ink
              now: sty.now
              born: modelData.t
              span: Math.min(modelData.d * 0.8, 0.5)
              rise: 0.1
              flicker: sty.blink
              gone: slot.line ? slot.line.out - 0.45 : Infinity
              seed: sty.seed
              salt: slot.lineIndex * 40 + 20 + index
            }
          }
        }
      }

      // The title out of focus: the same letters in the same place, on the soft plate. They go
      // on blinking there, as the print's do whether or not the lens is on them.
      Item {
        parent: sty.stage.softPlate
        x: slot.width / 2
        y: slot.height * 0.46
        scale: slot.creep
        visible: slot.up && slot.soft >= 0.02
        // The plate is not the style's own, so the style's fade at a cut is carried over by hand.
        opacity: (sty.parent ? sty.parent.opacity : 1) * Kinetic.span(0.02, 0.3, slot.soft) * (1 - slot.leaving)

        Row {
          x: slot.titleX
          y: slot.titleY
          spacing: sty.titleGap
          scale: slot.fit
          transformOrigin: Item.TopLeft

          Repeater {
            model: slot.titleWords

            LyricLetters {
              required property var modelData
              required property int index

              text: Kinetic.bare(modelData.text)
              caps: true
              family: Theme.lyricDidoneFont
              size: sty.titleSize
              color: sty.ink
              now: sty.now
              born: modelData.t
              span: 0
              rise: 0.01
              flicker: sty.blink * 2
              seed: sty.seed
              salt: slot.lineIndex * 40 + index
            }
          }
        }
      }
    }
  }
}
