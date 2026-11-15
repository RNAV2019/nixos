import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// One word at a time in tall, narrow capitals, each at its own tilt. As the next arrives the
// last is thrown out to a corner of the frame, where it stays large, turned and half out of
// shot; the line's final word holds the middle and is circled by hand, the pen going once
// round and a little past where it began.
FilmStyle {
  id: sty

  punchKick: 0.1

  // Where a thrown word comes to rest (as shares of the stage) and how it is turned there.
  readonly property var corners: [
    {
      x: 0.15,
      y: 0.09,
      turn: -13
    },
    {
      x: 0.86,
      y: 0.07,
      turn: 9
    },
    {
      x: 0.87,
      y: 0.94,
      turn: -11
    },
    {
      x: 0.19,
      y: 0.95,
      turn: 14
    }
  ]
  // The tall serif is drawn this much narrower than it was cut.
  readonly property real narrow: 0.7

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? (sty.lines[lineIndex] || null) : null
      readonly property int count: line ? line.words.length : 0
      // The word in hand, or -1 before the line's first.
      readonly property int at: {
        var k = -1;
        for (var i = 0; i < count; i++)
          if (sty.now >= line.words[i].t)
            k = i;
        return k;
      }
      readonly property int firstCorner: Math.floor(Kinetic.hash(sty.seed, lineIndex, 3) * 4)

      anchors.fill: parent
      visible: line !== null && at >= 0 && sty.now < line.out
      opacity: line ? 1 - Kinetic.span(line.out - 0.18, line.out - 0.02, sty.now) : 0

      Repeater {
        model: slot.line ? slot.line.words : []

        Item {
          id: piece

          required property var modelData
          required property int index

          readonly property bool last: index === slot.count - 1
          readonly property real age: sty.now - modelData.t
          readonly property real nextAt: !last && slot.line && index + 1 < slot.line.words.length ? slot.line.words[index + 1].t : Infinity
          // 0 in the middle, 1 at rest in its corner.
          // It is on its way a moment before the next word is due, so the middle is clear.
          readonly property real thrown: Kinetic.spring(sty.now - (nextAt - 0.14), 14, 1)
          readonly property var corner: sty.corners[(index + slot.firstCorner) % 4]
          readonly property real tilt: Kinetic.jitter(sty.seed, slot.lineIndex, index) * 9
          // A corner holds one word: this one goes when the fourth after it lands there.
          readonly property real kept: slot.line && index + 5 < slot.line.words.length ? 1 - Kinetic.span(0, 0.3, sty.now - slot.line.words[index + 5].t) : 1
          readonly property real held: Kinetic.span(modelData.t, Math.min(nextAt, slot.line ? slot.line.out : nextAt), sty.now)

          x: Kinetic.lerp(slot.width / 2, corner.x * slot.width, thrown)
          y: Kinetic.lerp(slot.height * 0.48, corner.y * slot.height, thrown)
          rotation: Kinetic.lerp(tilt, corner.turn, thrown)
          scale: (0.9 + 0.1 * Kinetic.outCubic(age / 0.22) + 0.07 * held) * Kinetic.lerp(1, 1.5, thrown)
          opacity: Kinetic.span(0.03, 0.16, age) * Kinetic.lerp(1, 0.5, thrown) * kept
          visible: age > 0 && opacity > 0.001
          z: last ? 1 : 0

          LyricText {
            id: word

            // Narrowed, it may be as wide as six tenths of the stage.
            readonly property real fit: Math.min(1, sty.width * 0.6 / Math.max(1, implicitWidth * sty.narrow))

            x: -width / 2
            y: -height / 2
            text: Kinetic.bare(piece.modelData.text)
            caps: true
            font.family: Theme.lyricTallSerifFont
            font.weight: Font.Normal
            size: 27 * sty.u
            color: sty.ink
            scale: fit
            transform: Scale {
              origin.x: word.width / 2
              xScale: sty.narrow
            }
          }

          // The pen: an ellipse a little larger than the word, begun at the top and drawn
          // clockwise, widening as it goes so its end overshoots its start. The stroke is laid
          // down in Shaders/lyricring.frag; only how far the pen has got changes from here.
          ShaderEffect {
            id: ring

            readonly property real rx: word.implicitWidth * sty.narrow * word.fit * 0.62 + 5 * sty.u
            readonly property real ry: 27 * sty.u * word.fit * 0.4 + 3.5 * sty.u
            readonly property real pen: 0.42 * sty.u

            property size itemSize: Qt.size(width, height)
            property size radii: Qt.size(rx, ry)
            property real stroke: pen
            property real drawn: Kinetic.outCubic((piece.age - 0.12) / 0.55)
            property real start: -112 * Math.PI / 180
            property real sweep: 394 * Math.PI / 180
            property real grow: 0.07
            property real aa: 1 / sty.stage.pixelRatio
            property color ink: sty.ink

            // Room for the widest turn and the pen's own width.
            width: 2 * rx * 1.08 + 4 * pen
            height: 2 * ry * 1.08 + 4 * pen
            x: -width / 2
            y: -height / 2
            visible: piece.last && drawn > 0
            rotation: -4 - piece.tilt * 0.5

            fragmentShader: Qt.resolvedUrl("../../Shaders/lyricring.frag.qsb")
          }
        }
      }
    }
  }
}
