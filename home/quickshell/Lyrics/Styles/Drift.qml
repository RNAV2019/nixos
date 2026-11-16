import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The song's lines as a wall seen from a little to one side, swaying slowly. The line in hand
// stands at a fixed height, whole and sharp; the ones sung climb away behind it, smaller and
// fainter, and the ones to come wait below, dim. A word fills with the cover's colour from the
// left as it is sung and lifts a little while it is, then cools to ink. What is not the line in
// hand is out of focus by how far off it is, which is the lens's doing (`depth`).
LyricStyle {
  id: sty

  // Where the line in hand begins, the type, and the distance from one line to the next.
  readonly property real inset: 0.117 * width
  readonly property real anchor: 0.4375 * height
  readonly property real size: 10.5 * u
  readonly property real pace: 14.75 * u
  // The widest a line may be before it is drawn smaller.
  readonly property real room: 0.76 * width
  // A word not yet sung.
  readonly property color waiting: Qt.rgba(ink.r, ink.g, ink.b, 0.26)

  depth: 0.9
  depthAt: (anchor + 0.6 * size) / Math.max(1, height)
  depthBand: 0.75 * size / Math.max(1, height)

  // The line in hand as a place in the column, gliding from the last line to this one.
  readonly property real at: {
    if (cur < 0)
      return -1;
    return cur - 1 + (Theme.reduceMotion ? 1 : Kinetic.spring(now - (lines[cur].t - lead), 9, 0.9));
  }

  // The wall's sway, in radians: turned away to the right and tipped back a little.
  readonly property real turn: (17 + (Theme.reduceMotion ? 0 : 4 * Math.sin(stage.wall * 0.5))) * Math.PI / 180
  readonly property real tip: (5 + (Theme.reduceMotion ? 0 : 2 * Math.sin(stage.wall * 0.37))) * Math.PI / 180

  // Where a line that sits at (px, py) on the wall, `pz` towards the eye and drawn at `s` of
  // its size, lands on the stage: the wall turned about the stage's middle and seen from a
  // little left of it. One matrix, flat (no depth comes out of it), as Qt's own 3D turns are.
  function sheet(px, py, pz, s) {
    var cx = width / 2;
    var cy = height / 2;
    var ox = 0.34 * width;
    var oy = 0.5 * height;
    var far = 1.375 * height;
    var ca = Math.cos(sty.tip);
    var sa = Math.sin(sty.tip);
    var cb = Math.cos(sty.turn);
    var sb = Math.sin(sty.turn);
    function seen(lx, ly) {
      var vx = px + s * lx - cx;
      var vy = py + s * ly - cy;
      var y1 = vy * ca - pz * sa;
      var z1 = vy * sa + pz * ca;
      var x2 = vx * cb + z1 * sb;
      var z2 = -vx * sb + z1 * cb;
      var w = 1 - z2 / far;
      return [x2 + cx - ox + ox * w, y1 + cy - oy + oy * w, w];
    }
    var o = seen(0, 0);
    var i = seen(1, 0);
    var j = seen(0, 1);
    return Qt.matrix4x4(i[0] - o[0], j[0] - o[0], 0, o[0], i[1] - o[1], j[1] - o[1], 0, o[1], 0, 0, 1, 0, i[2] - o[2], j[2] - o[2], 0, o[2]);
  }

  Repeater {
    model: 8

    Row {
      id: row

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 8, 4)
      readonly property var line: lineIndex >= 0 ? (sty.lines[lineIndex] || null) : null
      // Lines from the one in hand: negative for those sung.
      readonly property real k: lineIndex - sty.at
      readonly property real away: Math.abs(k)
      readonly property bool current: lineIndex === sty.cur
      // In hand it is whole; sung, it falls to half and then away; waiting, it is faint.
      readonly property real lit: k < 0 ? Math.max(0, 0.5 + 0.2 * k) * Math.min(1, 3 * away) + Math.max(0, 1 - 3 * away) : Math.max(0, 1 - away) + Math.min(1, away) * Math.max(0, 0.3 - 0.07 * away)
      // The line in hand dims once it is over, if nothing follows it for a while.
      readonly property real held: line && current && sty.parting(line) ? 1 - 0.65 * Kinetic.smooth(line.out, line.out + 0.6, sty.now) : 1

      spacing: 0.26 * sty.size
      opacity: lit * held
      visible: line !== null && opacity > 0.01

      transform: Matrix4x4 {
        matrix: sty.sheet(sty.inset + (row.k < 0 ? 3.25 * row.k : 0) * sty.u, sty.anchor + row.k * sty.pace, (row.k < 0 ? 21.25 * row.k : -5 * row.k) * sty.u, Math.min(1, sty.room / Math.max(1, row.implicitWidth)))
      }

      Repeater {
        model: row.line ? row.line.words : []

        Item {
          id: word

          required property var modelData
          required property int index

          readonly property real done: row.line ? sty.sung(row.line, index) : 0
          // How much of the word has filled: over its own length, or most of a second if it is
          // held longer than that.
          readonly property real filled: Kinetic.span(modelData.t, modelData.t + Math.min(Math.max(0.05, modelData.d), 0.9), sty.now)
          // 1 while it is the word being sung.
          readonly property real live: row.current && !Theme.reduceMotion ? Kinetic.smooth(modelData.t, modelData.t + 0.2, sty.now) * (1 - Kinetic.smooth(done, done + 0.3, sty.now)) : 0

          width: under.implicitWidth
          height: under.implicitHeight
          scale: 1 + 0.045 * live

          transform: Translate {
            y: -0.07 * sty.size * word.live
          }

          LyricText {
            id: under

            text: word.modelData.text
            size: sty.size
            font.weight: Font.ExtraBold
            tracking: -0.015
            color: sty.waiting
          }

          Item {
            width: word.filled >= 1 ? word.width : word.width * word.filled
            height: word.height
            clip: word.filled < 1
            visible: word.filled > 0

            LyricText {
              text: word.modelData.text
              size: sty.size
              font.weight: Font.ExtraBold
              tracking: -0.015
              color: sty.mix(sty.accent, sty.ink, (sty.now - word.done) / 0.6)
            }
          }
        }
      }
    }
  }
}
