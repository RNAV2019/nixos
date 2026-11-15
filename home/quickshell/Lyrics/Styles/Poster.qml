import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Each line is set as a poster: its words dealt into rows, every row sized to the same width,
// heavy rows against light ones. The posters are laid out across one big sheet, some turned a
// quarter, and a camera travels from one to the next as the lines come, turning with them; a
// word is not there until it is sung, so each poster builds under the voice.
LyricStyle {
  id: sty

  bloom: 0.4
  bloomKick: 0.3
  aberrationKick: 0.004
  punchKick: 0.12
  grain: 0.05

  // One poster's room on the sheet, and the gap to the next.
  readonly property real cellW: 100 * u
  readonly property real cellH: 62 * u
  readonly property real gap: 8 * u
  readonly property int count: first < 0 ? 0 : last - first + 1

  // Where each poster sits and which way up: every one beside the last, in the order below, so
  // no two share ground. "up" and "down" turn a quarter; the turned ones are as tall as a
  // poster is wide.
  readonly property var poses: {
    var out = [];
    var x = 0, y = 0, th = 0;
    var moves = ["up", "below", "down", "right"];
    var start = Math.floor(Kinetic.hash(seed, 7) * 4);
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        var move = moves[(i - 1 + start) % 4];
        // A quarter turn only from upright, and back only from turned.
        if (move === "up" && th !== 0)
          move = "below";
        if (move === "down" && th === 0)
          move = "right";
        var lx, ly;
        if (move === "below") {
          lx = 0;
          ly = cellH + gap;
        } else if (move === "right") {
          lx = cellW + 3 * gap;
          ly = 0;
        } else if (move === "up") {
          lx = cellW + gap;
          ly = cellH;
        } else {
          lx = cellW + gap + cellH;
          ly = 0;
        }
        var c = Math.cos(th), s = Math.sin(th);
        x += lx * c - ly * s;
        y += lx * s + ly * c;
        if (move === "up")
          th -= Math.PI / 2;
        else if (move === "down")
          th += Math.PI / 2;
      }
      var cc = Math.cos(th), ss = Math.sin(th);
      out.push({
        x: x,
        y: y,
        th: th,
        cx: x + cellW / 2 * cc - cellH / 2 * ss,
        cy: y + cellW / 2 * ss + cellH / 2 * cc
      });
    }
    return out;
  }

  // The camera: on the poster in hand, having come from the one before on a spring let go a
  // moment ahead of the line, and pushing in a little for as long as the line runs.
  readonly property int at: Math.max(0, cur - first)
  readonly property var to: count > 0 ? poses[at] : null
  readonly property var from: count > 0 ? poses[Math.max(0, at - 1)] : null
  readonly property real travel: line ? Kinetic.spring(now - (line.t - lead), 9, 0.82) : 1
  readonly property real push: line ? Kinetic.span(line.t, line.out, now) : 0
  readonly property real fitZoom: Math.min(width * 0.8 / cellW, height * 0.74 / cellH)

  Item {
    id: camera

    visible: sty.count > 0
    x: sty.width / 2
    y: sty.height / 2
    transformOrigin: Item.TopLeft
    scale: sty.fitZoom * (1 + 0.06 * sty.push)
    rotation: sty.to ? -Kinetic.lerp(sty.from.th, sty.to.th, sty.travel) * 180 / Math.PI : 0

    Item {
      x: sty.to ? -Kinetic.lerp(sty.from.cx, sty.to.cx, sty.travel) : 0
      y: sty.to ? -Kinetic.lerp(sty.from.cy, sty.to.cy, sty.travel) : 0

      Repeater {
        model: sty.count

        Item {
          id: poster

          required property int index

          readonly property int lineIndex: sty.first + index
          readonly property var line: sty.lines[lineIndex]
          readonly property var rows: Kinetic.rows(line.words)
          readonly property var pose: sty.poses[index]
          // In hand it is whole; the one before stays as a ghost while the camera leaves it.
          readonly property real ghost: lineIndex === sty.cur ? 1 : lineIndex === sty.cur - 1 ? 0.16 * (1 - Kinetic.span(0.5, 1.4, sty.now - sty.line.t)) + 0.84 * (1 - Kinetic.span(-sty.lead, 0.25, sty.now - sty.line.t)) : 0

          x: pose.x
          y: pose.y
          width: sty.cellW
          height: sty.cellH
          transformOrigin: Item.TopLeft
          rotation: pose.th * 180 / Math.PI
          opacity: ghost
          visible: ghost > 0.001

          Column {
            id: stack

            // A tall poster is drawn smaller, whole, in its room.
            readonly property real fit: Math.min(1, sty.cellH / Math.max(1, height))

            width: sty.cellW
            y: (sty.cellH - height) / 2
            scale: fit
            transformOrigin: Item.Center

            Repeater {
              model: poster.rows

              Item {
                id: band

                required property var modelData
                required property int index

                // Every other row is set light, starting on a different foot each poster.
                readonly property bool light: (index + Math.floor(Kinetic.hash(sty.seed, poster.lineIndex) * 2)) % 2 === 1 && poster.rows.length > 1
                readonly property real fit: sty.cellW / Math.max(1, strip.implicitWidth)

                width: sty.cellW
                // Capitals fill about three quarters of the line's own height.
                height: strip.implicitHeight * fit * 0.78

                Row {
                  id: strip

                  y: -strip.implicitHeight * band.fit * 0.1
                  spacing: 2.6 * sty.u
                  scale: band.fit
                  transformOrigin: Item.TopLeft

                  Repeater {
                    model: band.modelData

                    LyricText {
                      id: word

                      required property int modelData

                      readonly property var w: poster.line.words[modelData]
                      readonly property real age: sty.now - w.t
                      readonly property real land: Kinetic.spring(age, 26, 0.6)

                      text: Kinetic.bare(w.text)
                      caps: true
                      size: 12 * sty.u
                      font.weight: band.light ? Font.Light : Font.Black
                      font.letterSpacing: band.light ? 0 : -0.2 * sty.u
                      color: sty.mix(sty.accent, sty.ink, (age - w.d) / 0.5)
                      opacity: Kinetic.clamp01(age / 0.07)
                      scale: 1 + 0.25 * (1 - land)
                      transform: Translate {
                        y: (1 - word.land) * 4 * sty.u
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
  }
}
