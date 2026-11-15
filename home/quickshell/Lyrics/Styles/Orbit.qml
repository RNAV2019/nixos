import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The line's words stand round a carousel seen from a little above, turning about its upright:
// as each word is sung the ring swings it round to the front, where it is largest and in the
// accent, and the rest wait round the sides and the back, smaller and dimmer the further they
// are. Each new line's ring rises into place as the last one sinks away behind it, and between
// words the ring rocks a little on its own, so it never stands dead still.
LyricStyle {
  id: sty

  bloom: 0.5
  bloomKick: 0.3
  aberration: 0.0014
  aberrationKick: 0.004
  punchKick: 0.08
  grain: 0.05
  vignette: 0.5
  ground: 1

  // The ring's radius, and the eye's distance from its middle in radii: nearer is steeper.
  readonly property real radius: width * 0.3
  readonly property real eye: 2.4
  readonly property real nearest: eye / (eye - 1)
  // How far below the eye the ring is, as the front word's drop from the middle.
  readonly property real drop: (13 + 3 * Math.sin(stage.wall * 0.7)) * u

  Repeater {
    model: 3

    Item {
      id: ring

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      readonly property int count: line ? line.words.length : 0
      // Evenly round the ring; one or two words are spaced as if there were four, so a pair
      // stands front and side rather than front and back.
      readonly property real step: 2 * Math.PI / Math.max(4, count)
      // How far the ring has turned: one step for each word sung, every one on its own spring,
      // so a quick run of words winds it on smoothly instead of jumping between targets.
      readonly property real spin: {
        var a = 0;
        for (var k = 1; k < count; k++)
          a += step * Kinetic.spring(sty.now - line.words[k].t + 0.08, 11, 0.78);
        return a + 0.05 * Math.sin(sty.stage.wall * 0.5);
      }
      // The word being sung, or -1 before the first.
      readonly property int sung: {
        var j = -1;
        for (var k = 0; k < count; k++)
          if (line.words[k].t <= sty.now)
            j = k;
        return j;
      }
      // Sinking away first, then the next one rising into the room it left: the old ring is
      // down and gone a moment before the new one's first word, and never sinks before its own
      // last word is done unless that word runs to the next line.
      readonly property real sinkAt: line ? Math.min(Math.max(line.end - 0.1, line.out - 0.75), line.out - 0.3) : 0
      readonly property real rise: !line || sty.cur < 0 ? 0 : Kinetic.outCubic(lineIndex === sty.first ? Kinetic.span(line.t - sty.lead, line.t, sty.now) : Kinetic.span(line.t - 0.3, line.t + 0.05, sty.now))
      readonly property real sink: line ? Kinetic.inCubic(Kinetic.span(sinkAt, sinkAt + 0.42, sty.now)) : 0

      anchors.fill: parent
      visible: rise > 0 && sink < 1
      opacity: Math.min(rise, 1 - sink)

      Item {
        id: hub

        x: ring.width / 2
        y: ring.height * 0.42 + (1 - ring.rise) * 22 * sty.u + ring.sink * 14 * sty.u
        scale: (0.82 + 0.18 * ring.rise) * (1 - 0.45 * ring.sink)
        rotation: 1.6 * Math.sin(sty.stage.wall * 0.37 + ring.lineIndex)

        Repeater {
          model: ring.line ? ring.line.words : []

          LyricText {
            id: word

            required property var modelData
            required property int index

            readonly property real angle: index * ring.step - ring.spin
            readonly property real depth: Math.cos(angle)
            // Perspective: nearer is larger, further out to the side and lower down.
            readonly property real near: sty.eye / (sty.eye - depth)
            readonly property real fit: Math.min(1, sty.width * 0.42 / Math.max(1, implicitWidth))
            readonly property real lit: Kinetic.span(modelData.t, modelData.t + 0.12, sty.now)
            // In front, the word in hand turns to the accent; sung words stay ink, the
            // ones to come wait dim.
            readonly property real fade: 0.1 + 0.9 * Math.pow((depth + 1) / 2, 1.6)

            x: Math.sin(angle) * sty.radius * near - width / 2
            y: depth * sty.drop * near - height / 2
            z: depth
            text: Kinetic.bare(modelData.text)
            font.family: Theme.lyricGroteskFont
            font.weight: Font.Normal
            size: 20 * sty.u
            color: index === ring.sung ? sty.accent : sty.ink
            opacity: fade * (0.32 + 0.68 * lit)
            scale: fit * near / sty.nearest * (1 + (index === ring.sung ? 0.08 * (1 - Kinetic.spring(sty.now - modelData.t, 18, 0.5)) : 0))
            transform: Scale {
              // Turned away from the eye, a word narrows as on the ring's own surface.
              origin.x: word.width / 2
              xScale: 0.45 + 0.55 * Math.max(0, word.depth) + 0.3 * Math.max(0, -word.depth)
            }
          }
        }
      }
    }
  }
}
