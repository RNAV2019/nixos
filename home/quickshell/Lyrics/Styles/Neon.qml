import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Each line is a neon sign: its words bent in tubes, in rows, the whole sign hung a little
// askew on the dark. The tubes are there before they are sung, unlit glass you can only just
// make out; each word strikes on as it is sung (two or three stutters, as a real tube does when
// the gas catches), then burns steady with a faint mains buzz. When the line is done the sign
// switches off word by word, and the next sign is already hanging there, waiting, unlit.
LyricStyle {
  id: sty

  bloom: 1.35
  bloomKick: 0.45
  aberration: 0.0018
  aberrationKick: 0.002
  grain: 0.05
  vignette: 0.5
  ground: 0.7

  // Unlit glass, as a share of a lit tube.
  readonly property real glass: 0.08
  // How long a word's strike stutters, and the step of each stutter.
  readonly property real strike: 0.18
  readonly property real stutter: 0.03
  // The tube letters' size before the sign is fitted.
  readonly property real tube: 10 * u

  // A line's words dealt into rows of about eleven letters each (tube capitals are wide, and a
  // sign reads best broad rather than tall), the letters shared evenly between the rows.
  function deal(words) {
    var lengths = words.map(function (w) {
      return Kinetic.bare(w.text).length + 1;
    });
    var total = lengths.reduce(function (a, b) {
      return a + b;
    }, 0);
    var n = Math.max(1, Math.min(4, words.length, Math.round(total / 11)));
    var out = [], row = [], done = 0;
    for (var i = 0; i < words.length; i++) {
      // A word starts a new row when the row so far is past its share by more than half it.
      if (row.length > 0 && out.length < n - 1 && done + lengths[i] / 2 > total * (out.length + 1) / n) {
        out.push(row);
        row = [];
      }
      row.push(i);
      done += lengths[i];
    }
    out.push(row);
    return out;
  }

  // When a sign starts switching off, how long it takes to reach its last word, and when the
  // last of its glass has gone: quick, so the next sign has a moment hanging dark before its
  // first word.
  function offAt(line) {
    return Math.max(line.end, line.out - 0.9);
  }
  function offRun(line) {
    return Math.max(0.08, Math.min(0.4, line.out - 0.45 - offAt(line)));
  }
  function darkAt(line) {
    return offAt(line) + offRun(line) + 0.18;
  }

  FontMetrics {
    id: tubeMetrics

    font.family: Theme.lyricNeonFont
    font.pixelSize: Math.round(sty.tube)
  }

  FontMetrics {
    id: scriptMetrics

    font.family: "Pacifico"
    font.pixelSize: Math.round(sty.tube * 1.3)
  }

  Repeater {
    model: 3

    Item {
      id: sign

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      readonly property var rows: line ? sty.deal(line.words) : []
      // The line's longest held word is bent in script; the rest are tube capitals. A line of
      // one or two words is all capitals, or it would read as a word and a flourish.
      readonly property int script: {
        if (!line || line.words.length < 3)
          return -1;
        var best = -1, held = 0;
        for (var j = 0; j < line.words.length; j++) {
          var w = line.words[j];
          if (Kinetic.bare(w.text).length >= 3 && w.d >= held) {
            best = j;
            held = w.d;
          }
        }
        return best;
      }
      // The sign comes up unlit once the one before has gone dark (the segment's first as its
      // line comes due), and is gone by the line's leaving.
      readonly property real hang: {
        if (!line || sty.cur < 0)
          return 0;
        var up;
        if (lineIndex === sty.first)
          up = Kinetic.span(line.t - sty.lead, line.t - sty.lead + 0.2, sty.now);
        else {
          // Never later than its own first word, when the one before was held to the last.
          var dark = Math.min(sty.darkAt(sty.lines[lineIndex - 1]), line.t - 0.2);
          up = Kinetic.span(dark, dark + 0.2, sty.now);
        }
        return up * (1 - Kinetic.span(line.out - 0.1, line.out, sty.now));
      }
      readonly property real offAt: line ? sty.offAt(line) : 0
      readonly property real offRun: line ? sty.offRun(line) : 0
      // Each sign hangs in its own place, a little off true, so the next sign waiting is not
      // drawn exactly over the one going dark.
      readonly property real dx: Kinetic.jitter(sty.seed, lineIndex, 1) * 4 * sty.u
      readonly property real dy: Kinetic.jitter(sty.seed, lineIndex, 2) * 4 * sty.u
      readonly property real tilt: Kinetic.jitter(sty.seed, lineIndex, 3) * 2.2

      anchors.fill: parent
      visible: hang > 0

      Column {
        id: board

        readonly property real fit: Math.min(1.8, sty.width * 0.84 / Math.max(1, implicitWidth), sty.height * 0.62 / Math.max(1, implicitHeight))

        x: (sign.width - width) / 2 + sign.dx
        y: (sign.height - height) / 2 + sign.dy
        spacing: 1.2 * sty.u
        scale: fit
        rotation: sign.tilt
        transformOrigin: Item.Center

        Repeater {
          model: sign.rows

          Row {
            id: row

            required property var modelData

            readonly property bool scripted: modelData.indexOf(sign.script) >= 0
            // Words sit on one baseline whether they are tubes or script.
            readonly property real base: scripted ? Math.max(tubeMetrics.ascent, scriptMetrics.ascent * 0.72) : tubeMetrics.ascent

            anchors.horizontalCenter: parent.horizontalCenter
            height: scripted ? base + Math.max(tubeMetrics.descent, scriptMetrics.descent * 0.6) : tubeMetrics.height
            spacing: 2.4 * sty.u

            Repeater {
              model: row.modelData

              LyricText {
                id: word

                required property int modelData

                readonly property var w: sign.line.words[modelData]
                readonly property bool isScript: modelData === sign.script
                readonly property real age: sty.now - w.t
                readonly property int key: sign.lineIndex * 97 + modelData
                // How bright the tube is, glass to burning: struck in stutters, then steady.
                readonly property real lit: {
                  if (age < 0)
                    return 0;
                  if (age >= sty.strike)
                    return 1;
                  var step = Math.floor(age / sty.stutter);
                  var on = step === 0 || step >= Math.floor(sty.strike / sty.stutter) - 1 || Kinetic.hash(sty.seed + 17, key, step) > 0.5;
                  return on ? 0.55 + 0.45 * Kinetic.hash(sty.seed + 23, key, step) : 0.1;
                }
                // Switching off, word by word, each with one last catch before it goes.
                readonly property real offAge: sty.now - (sign.offAt + sign.offRun * modelData / Math.max(1, sign.line.words.length))
                readonly property real dark: offAge < 0 ? 0 : offAge < 0.03 ? 0.85 : offAge < 0.06 ? 0.3 : offAge < 0.085 ? 0.7 : 1
                // The mains: a few percent of wobble, and now and then a tired tube catches.
                readonly property real buzz: 1 - 0.03 * (0.5 + 0.5 * Math.sin(sty.stage.wall * 37.7 + modelData * 1.9)) - 0.25 * (Kinetic.hash(sty.seed, key, 5) < 0.2 && ((sty.stage.wall * 0.31 + Kinetic.hash(sty.seed, key, 6)) % 1) < 0.012 ? 1 : 0)
                readonly property real glow: lit * (1 - dark) * buzz
                readonly property color tone: modelData % 2 === 0 ? sty.accent : sty.accent2

                y: row.base - (isScript ? scriptMetrics.ascent : tubeMetrics.ascent)
                text: isScript ? Kinetic.bare(w.text).toLowerCase() : Kinetic.bare(w.text)
                font.family: isScript ? "Pacifico" : Theme.lyricNeonFont
                font.weight: Font.Normal
                caps: !isScript
                size: isScript ? sty.tube * 1.3 : sty.tube
                color: sty.mix(sty.ink, tone, 0.35 + 0.65 * glow)
                // Switched off, the glass goes too, so the sign is gone before the next one hangs.
                opacity: Math.max(sty.glass * (1 - Kinetic.span(0.1, 0.25, offAge)), glow) * sign.hang
              }
            }
          }
        }
      }
    }
  }
}
