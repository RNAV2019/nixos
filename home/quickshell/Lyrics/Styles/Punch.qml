import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// One word at a time, and it owns the screen, in the cover's colour. Words take turns at three
// ways in: from too large, from below with a tilt, from the left on a slant. A word swells and
// its letters draw apart for as long as it is held, so a long note stretches, and it leaves
// upwards as the next one lands. Each landing throws a bloom of light behind the word and puts
// it out of focus for a moment (the lens's `depth`). The line the word belongs to runs small
// underneath, filling in as it is sung, so the eye can keep its place.
LyricStyle {
  id: sty

  // The size a word is measured and drawn at before it is fitted.
  readonly property real ref: 100

  FontMetrics {
    id: heavy

    font.family: Theme.lyricFont
    font.weight: Font.Black
    font.pixelSize: sty.ref
    font.letterSpacing: -0.03 * sty.ref
  }

  // How many words come before each line, so the three ways in go round the whole song.
  readonly property var before: {
    var out = [];
    var n = 0;
    for (var i = 0; i < sty.lines.length; i++) {
      out.push(n);
      n += sty.lines[i].words.length;
    }
    return out;
  }

  // Seconds since the last word landed.
  readonly property real sinceHit: {
    var best = 99;
    for (var i = Math.max(0, sty.cur - 1); i <= sty.cur; i++) {
      var words = sty.lines[i].words;
      for (var j = 0; j < words.length; j++) {
        var age = sty.now - words[j].t;
        if (age >= 0 && age < best)
          best = age;
      }
    }
    return best;
  }

  // Everything above the small line is out of focus while a word lands.
  depth: Theme.reduceMotion ? 0 : 2.2 * (1 - Kinetic.smooth(0, 0.32, sinceHit))
  depthAt: 0.9
  depthBand: 0.13

  // The bloom behind the word: the cover's colour, brightest in the middle, gone at its edge.
  Shape {
    id: bloom

    width: 100 * sty.u
    height: width
    x: (sty.width - width) / 2
    y: (sty.height - height) / 2
    opacity: Theme.reduceMotion ? 0 : 0.55 * Math.exp(-3 * sty.sinceHit)
    visible: opacity > 0.004
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: -1
      fillGradient: RadialGradient {
        centerX: bloom.width / 2
        centerY: bloom.height / 2
        centerRadius: bloom.width / 2
        focalX: centerX
        focalY: centerY

        GradientStop {
          position: 0
          color: Qt.rgba(sty.accent.r, sty.accent.g, sty.accent.b, 0.5)
        }

        GradientStop {
          position: 1
          color: Qt.rgba(sty.accent.r, sty.accent.g, sty.accent.b, 0)
        }
      }

      PathAngleArc {
        centerX: bloom.width / 2
        centerY: bloom.height / 2
        radiusX: bloom.width / 2
        radiusY: bloom.height / 2
        startAngle: 0
        sweepAngle: 360
      }
    }
  }

  Repeater {
    model: 3

    Item {
      id: slot

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? (sty.lines[lineIndex] || null) : null

      anchors.fill: parent

      Repeater {
        model: slot.line ? slot.line.words : []

        Item {
          id: hit

          required property var modelData
          required property int index

          readonly property real age: sty.now - modelData.t
          readonly property real until: slot.line ? sty.until(slot.line, index) : 0
          // Which of the three ways in this word takes.
          readonly property int way: slot.lineIndex >= 0 && slot.lineIndex < sty.before.length ? (sty.before[slot.lineIndex] + index) % 3 : 0
          // 0 as it lands to 1 in place, a touch past and back; how far through its hold; and
          // 0 to 1 as it leaves.
          readonly property real land: Theme.reduceMotion ? 1 : Kinetic.outBack(age / 0.34, 0.5)
          readonly property real held: Kinetic.span(modelData.t, until, sty.now)
          readonly property real leave: Kinetic.inCubic((sty.now - until) / (Theme.reduceMotion ? 0.01 : 0.3))

          anchors.fill: parent
          visible: age > 0 && sty.now < until + 0.3
          opacity: Kinetic.clamp01(age / 0.1) * (1 - leave)

          LyricText {
            id: word

            readonly property string shown: (Kinetic.bare(hit.modelData.text) || hit.modelData.text).toUpperCase()
            // Its width before the hold draws its letters apart.
            readonly property real rest: {
              heavy.height;
              return heavy.advanceWidth(shown);
            }
            // As wide as the stage lets it be, and no taller than a word of its length in
            // time may be: a held note is set larger than a passing one.
            readonly property real fit: Math.min(0.7 * sty.width / Math.max(1, rest), (18.75 + 13.75 * Math.min(hit.modelData.d, 1.6)) * sty.u / sty.ref)

            x: (hit.width - width) / 2 - (hit.way === 2 ? (1 - hit.land) * 25 * sty.u : 0)
            y: 0.4125 * hit.height - height / 2 + (hit.way === 1 ? (1 - hit.land) * 20 * sty.u : 0) - hit.leave * 13.75 * sty.u
            text: shown
            size: sty.ref
            tracking: -0.03 + 0.065 * hit.held
            color: sty.accent
            scale: fit * (hit.way === 0 ? 1 + 0.7 * (1 - hit.land) : 1) * (1 + 0.07 * hit.held) * (1 - 0.08 * hit.leave)
            rotation: hit.way === 1 ? 5 * (1 - hit.land) : 0

            // The slant of the third way in: the top of the word leans back and comes upright.
            transform: Matrix4x4 {
              readonly property real lean: hit.way === 2 ? Math.tan(-14 * Math.PI / 180 * (1 - hit.land)) : 0

              matrix: Qt.matrix4x4(1, lean, 0, -lean * word.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
          }
        }
      }

      // The line, small, under the word.
      Row {
        id: strip

        readonly property real up: slot.line ? Kinetic.span(slot.line.t - sty.lead, slot.line.t, sty.now) * (1 - Kinetic.span(slot.line.out - 0.2, slot.line.out, sty.now)) : 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.83
        spacing: 1.1 * sty.u
        opacity: up
        visible: up > 0
        scale: Math.min(1, 0.9 * sty.width / Math.max(1, implicitWidth))

        Repeater {
          model: slot.line ? slot.line.words : []

          LyricText {
            required property var modelData

            text: modelData.text
            font.weight: Font.DemiBold
            size: 3.1 * sty.u
            tracking: 0.02
            color: sty.ink
            opacity: 0.3 + 0.7 * Kinetic.span(modelData.t, modelData.t + 0.25, sty.now)
          }
        }
      }
    }
  }
}
