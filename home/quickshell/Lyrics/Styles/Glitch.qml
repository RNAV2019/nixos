import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Signal failure, kept to the beat. The line is set in blocky monospaced capitals (pixel type
// when it is short), one to three rows, and each word arrives as a burst of noise: its letters
// scrambled for a few frames on an inverted plate, then decoded, white, with its red and blue
// ghosts knocked off register and snapping back. The lens tears rows and splits colour on each
// hit; between hits the line holds still and plain, so it can be read. It drops out in a stutter.
LyricStyle {
  id: sty

  bloom: 0.4
  bloomKick: 0.35
  aberration: 0.0015
  aberrationKick: 0.014
  glitchKick: 1.3
  shakeKick: 0.22
  scan: 0.3
  grain: 0.1
  vignette: 0.45
  ground: 0.8

  // How long a word stays noise, and how often the noise changes.
  readonly property real noise: 0.09
  readonly property real tick: 0.03
  readonly property string junk: "ABCDEFGHJKLMNPRSTUVWXYZ0123456789#%&*+=?!<>/"
  // The type's size before a line is fitted.
  readonly property real type: 8 * u

  // The bare letters of a line, counted.
  function letters(words) {
    var n = 0;
    for (var i = 0; i < words.length; i++)
      n += Kinetic.bare(words[i].text).length + 1;
    return n;
  }

  // A line's words dealt into rows of about even letters: one for a short line, three at most.
  function deal(words) {
    var total = letters(words);
    var n = Math.max(1, Math.min(3, words.length, total <= 13 ? 1 : total <= 28 ? 2 : 3));
    var out = [], row = [], done = 0;
    for (var i = 0; i < words.length; i++) {
      var l = Kinetic.bare(words[i].text).length + 1;
      if (row.length > 0 && out.length < n - 1 && done + l / 2 > total * (out.length + 1) / n) {
        out.push(row);
        row = [];
      }
      row.push(i);
      done += l;
    }
    out.push(row);
    return out;
  }

  // `text` as noise `age` seconds into a word: each letter decodes in turn, left to right, and
  // until it does it is a random character that changes every tick.
  function scramble(text, age, key) {
    if (age >= noise)
      return text;
    var step = Math.floor(Math.max(0, age) / tick);
    var out = "";
    for (var k = 0; k < text.length; k++) {
      if (age >= noise * (0.35 + 0.65 * (k + 1) / text.length))
        out += text[k];
      else
        out += junk[Math.floor(Kinetic.hash(seed + step * 7919, key, k) * junk.length)];
    }
    return out;
  }

  Repeater {
    model: 3

    Item {
      id: block

      required property int index

      readonly property int lineIndex: sty.slotLine(index, 3)
      readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
      readonly property var rows: line ? sty.deal(line.words) : []
      // Pixel type for a short line; it is too wide for a long one.
      readonly property bool pixel: line ? sty.letters(line.words) <= 24 : false
      // Its last moments: a few ticks of stutter, then gone by the line's leaving.
      readonly property real remain: line ? line.out - sty.now : 1
      readonly property int step: Math.floor(sty.now / sty.tick)
      readonly property bool dropped: remain < 0.2 && (remain < 0.05 || Kinetic.hash(sty.seed, lineIndex, step) < 0.45)

      anchors.fill: parent
      visible: line !== null && sty.cur >= 0 && remain > 0 && !dropped

      Column {
        id: board

        readonly property real fit: Math.min(1.7, sty.width * 0.86 / Math.max(1, implicitWidth), sty.height * 0.6 / Math.max(1, implicitHeight))

        x: (block.width - width) / 2
        y: (block.height - height) / 2
        spacing: (block.pixel ? 3 : 1) * sty.u
        scale: fit
        transformOrigin: Item.Center

        Repeater {
          model: block.rows

          Row {
            id: row

            required property var modelData
            required property int index

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: (block.pixel ? 3.2 : 2.2) * sty.u
            // In the stutter out each row is thrown sideways on its own.
            transform: Translate {
              x: block.remain < 0.2 ? Kinetic.jitter(sty.seed + block.step, block.lineIndex, row.index) * 6 * sty.u : 0
            }

            Repeater {
              model: row.modelData

              Item {
                id: word

                required property int modelData

                readonly property var w: block.line.words[modelData]
                readonly property real age: sty.now - w.t
                readonly property int key: block.lineIndex * 97 + modelData
                readonly property bool noisy: age < sty.noise
                // The ghosts' throw: knocked out of register as the word decodes, held there two
                // ticks, then back in steps (a signal, not a spring) by a quarter second; and a
                // nudge on every hit.
                readonly property real throwAt: Math.floor(Math.max(0, age - sty.noise - 0.05) / 0.025) * 0.025
                readonly property real split: (1 - Kinetic.spring(throwAt, 18, 0.55)) * 0.22 + 0.05 * sty.stage.kick
                readonly property real angle: Kinetic.hash(sty.seed, key, 3) * Math.PI * 2
                readonly property real sx: Math.cos(angle) * split * face.font.pixelSize
                readonly property real sy: Math.sin(angle) * split * 0.4 * face.font.pixelSize

                width: face.implicitWidth
                height: face.implicitHeight
                // Not `visible`: a Row closes up over a hidden item, and a word keeps its room
                // in the line before it is sung.
                opacity: age >= 0 ? 1 : 0

                // The inverted plate the noise sits on.
                Rectangle {
                  x: -0.12 * face.font.pixelSize
                  y: face.font.pixelSize * (block.pixel ? -0.08 : 0.08)
                  width: parent.width + 0.24 * face.font.pixelSize
                  height: block.pixel ? face.font.pixelSize * 1.16 : parent.height * 0.84
                  color: sty.accent
                  visible: word.noisy
                }

                LyricText {
                  x: word.sx
                  y: word.sy
                  text: face.text
                  font.family: face.font.family
                  size: face.size
                  caps: true
                  color: sty.accent
                  visible: !word.noisy && Math.abs(word.split) > 0.02
                }

                LyricText {
                  x: -word.sx
                  y: -word.sy
                  text: face.text
                  font.family: face.font.family
                  size: face.size
                  caps: true
                  color: sty.accent2
                  visible: !word.noisy && Math.abs(word.split) > 0.02
                }

                LyricText {
                  id: face

                  text: sty.scramble(Kinetic.bare(word.w.text).toUpperCase(), word.age, word.key)
                  font.family: block.pixel ? Theme.lyricPixelFont : "Rubik Mono One"
                  font.weight: Font.Normal
                  size: block.pixel ? sty.type * 0.8 : sty.type
                  caps: true
                  color: word.noisy ? "#000000" : sty.ink
                }
              }
            }
          }
        }
      }
    }
  }
}
