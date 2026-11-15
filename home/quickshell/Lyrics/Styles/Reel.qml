import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// A focus pull. The first half of the line comes up as a title, in fat capitals; as the second
// half begins the title goes out of focus and falls back, the projector's lamp swells behind,
// and the rest is written over it in script, a letter at a time. Letters blink out now and then
// as on a worn print, and at the end the script goes letter by letter. A line of three words or
// fewer is all title.
FilmStyle {
  id: sty

  // The word the script begins at; the line's length when there is none.
  function split(line) {
    var n = line.words.length;
    return n >= 4 ? Math.ceil(n / 2) : n;
  }

  readonly property real scriptAt: line && split(line) < line.words.length ? line.words[split(line)].t : Infinity

  // The lamp comes up with the script and is down again before the line goes.
  spot: line ? 0.3 * Kinetic.smooth(scriptAt - 0.25, scriptAt + 0.9, now) * (1 - Kinetic.span(line.out - 0.5, line.out - 0.05, now)) : 0
  spotSize: 0.36
  spotAt: Qt.point(0.45 + 0.03 * Math.sin(stage.wall * 0.21), 0.56 + 0.03 * Math.cos(stage.wall * 0.17))

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
      // How far out of focus the title is.
      readonly property real soft: Kinetic.smooth(scriptAt - 0.1, scriptAt + 0.7, sty.now)
      readonly property real leaving: line ? Kinetic.span(line.out - 0.4, line.out - 0.05, sty.now) : 0
      readonly property real push: line ? Kinetic.span(line.t, line.out, sty.now) : 0

      anchors.fill: parent
      visible: line !== null && sty.now > line.t - 0.05 && sty.now < line.out

      Item {
        x: slot.width / 2
        y: slot.height * 0.46
        // The camera creeps in for as long as the line is held.
        scale: 1 + 0.05 * slot.push

        // The title. In focus it is drawn once, letter by letter. Out of focus it is drawn as a
        // ring of faint copies spreading from where it stood, which is what a lens does to a
        // point of light: the stage keeps to plain items here, since a blur of its own would
        // mean a layer per line, made and thrown away with every line.
        Item {
          id: title

          readonly property real fit: Math.min(1, sty.width * 0.74 / Math.max(1, titleRow.implicitWidth))
          readonly property real size: 14 * sty.u
          readonly property real gap: 3.4 * sty.u
          // How far the copies stand from the middle.
          readonly property real spread: slot.soft * 1.7 * sty.u

          width: titleRow.implicitWidth * fit
          height: titleRow.implicitHeight * fit
          x: -width / 2
          y: -height / 2 - slot.soft * 1.5 * sty.u
          opacity: (1 - 0.5 * slot.soft) * (slot.scriptWords.length > 0 ? 1 - slot.leaving : 1)

          Row {
            id: titleRow

            spacing: title.gap
            scale: title.fit
            transformOrigin: Item.TopLeft
            visible: slot.soft < 0.03

            Repeater {
              model: slot.titleWords

              LyricLetters {
                required property var modelData
                required property int index

                text: Kinetic.bare(modelData.text)
                caps: true
                family: Theme.lyricDidoneFont
                size: title.size
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

          Repeater {
            model: slot.soft >= 0.03 ? 17 : 0

            Row {
              required property int index

              // One in the middle, eight round it and eight more between, half as far out.
              readonly property real turn: index * Math.PI / 4 + (index > 8 ? Math.PI / 8 : 0)
              readonly property real reach: index === 0 ? 0 : index > 8 ? 0.55 : 1

              x: Math.cos(turn) * title.spread * reach
              y: Math.sin(turn) * title.spread * reach
              spacing: title.gap
              scale: title.fit
              transformOrigin: Item.TopLeft
              opacity: 0.12

              Repeater {
                model: slot.titleWords

                LyricText {
                  required property var modelData

                  text: Kinetic.bare(modelData.text)
                  caps: true
                  font.family: Theme.lyricDidoneFont
                  font.weight: Font.Normal
                  size: title.size
                  color: sty.ink
                }
              }
            }
          }
        }

        // The script, over the lower half of the title.
        Row {
          id: script

          readonly property real fit: Math.min(1, sty.width * 0.7 / Math.max(1, implicitWidth))

          x: -implicitWidth * fit / 2 + 2 * sty.u
          y: -implicitHeight * fit / 2 + 6.5 * sty.u
          spacing: 3 * sty.u
          scale: fit
          transformOrigin: Item.TopLeft

          Repeater {
            model: slot.scriptWords

            LyricLetters {
              required property var modelData
              required property int index

              text: Kinetic.bare(modelData.text).toLowerCase()
              family: Theme.lyricScriptFont
              size: 20 * sty.u
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
    }
  }
}
