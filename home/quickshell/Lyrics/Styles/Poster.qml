import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Each line is set as a poster: its words dealt into rows, every row sized to the same width,
// the rows that carry the line heavy and the ones that only pass light. A word lands in its
// place as it is sung, in the cover's colour, and cools to ink once it has been. The next line
// is set beside the last, below it or to its right, every other one turned a quarter, and the
// camera travels and turns to it, so the line in hand is always upright and fills the stage
// while the one before hangs dim at the edge.
LyricStyle {
  id: sty

  // A block is laid out in units of its own, `across` of them wide, from type measured at
  // `ref`; the camera says how many pixels a unit is.
  readonly property real across: 1000
  readonly property real ref: 100
  // Between one block and the next.
  readonly property real gap: 60
  // The largest a row's type may be (a row of one short word would otherwise be the whole
  // block), and a row's advance as a share of its type size: capitals have no descenders.
  readonly property real tallest: 330
  readonly property real leading: 0.86

  FontMetrics {
    id: heavy

    font.family: Theme.lyricFont
    font.weight: Font.Black
    font.pixelSize: sty.ref
    font.letterSpacing: -0.02 * sty.ref
  }

  FontMetrics {
    id: light

    font.family: Theme.lyricFont
    font.weight: Font.Light
    font.pixelSize: sty.ref
  }

  TextMetrics {
    id: capital

    font: heavy.font
    text: "H"
  }

  // How far below a word's top its capitals begin, and how tall they are, at `ref`.
  readonly property real capHeight: capital.tightBoundingRect.height
  readonly property real capTop: heavy.ascent - capHeight

  // Words that pass rather than carry: a row made only of these is set light.
  readonly property var passing: ({
      "with": true,
      "from": true,
      "that": true,
      "this": true,
      "than": true,
      "then": true,
      "they": true,
      "them": true,
      "your": true,
      "into": true,
      "when": true,
      "what": true,
      "have": true,
      "been": true,
      "were": true,
      "will": true
    })

  function passes(text) {
    var b = Kinetic.bare(text).toLowerCase();
    return b.length <= 3 || sty.passing[b] === true;
  }

  // A line as a block: its rows, each with its scale, its distance down and its words' places
  // along it, and the block's height from the first row's capitals to the last row's foot.
  function block(line) {
    var groups = Kinetic.rows(line.words);
    var rows = [];
    var carried = false;
    var lightened = false;
    var longest = 0;
    var most = -1;
    for (var r = 0; r < groups.length; r++) {
      var slight = 0;
      var chars = 0;
      for (var g = 0; g < groups[r].length; g++) {
        var text = line.words[groups[r][g]].text;
        if (sty.passes(text))
          slight++;
        chars += Kinetic.bare(text).length;
      }
      var thin = groups.length > 1 && slight === groups[r].length;
      if (thin)
        lightened = true;
      else
        carried = true;
      if (chars > most) {
        most = chars;
        longest = r;
      }
      rows.push({
        thin: thin,
        chars: chars,
        slight: slight / groups[r].length,
        indices: groups[r]
      });
    }
    // Something has to carry the line.
    if (!carried)
      rows[longest].thin = false;
    // And a block of three rows or more wants one of them light, or it is a slab: the row
    // that carries least, but never the last, which is where the line lands.
    if (!lightened && rows.length >= 3) {
      var least = -1;
      for (var q = 0; q < rows.length - 1; q++)
        if (q !== longest && rows[q].slight > 0 && (least < 0 || rows[q].slight > rows[least].slight))
          least = q;
      if (least >= 0)
        rows[least].thin = true;
    }
    var y = 0;
    var last = 0;
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      var m = row.thin ? light : heavy;
      var space = m.advanceWidth(" ");
      var x = 0;
      var words = [];
      for (var j = 0; j < row.indices.length; j++) {
        var word = line.words[row.indices[j]];
        var shown = (Kinetic.bare(word.text) || word.text).toUpperCase();
        var w = m.advanceWidth(shown);
        words.push({
          j: row.indices[j],
          text: shown,
          x: x,
          w: w,
          word: word
        });
        x += w + space;
      }
      row.k = Math.min(sty.across / Math.max(1, x - space), sty.tallest / sty.ref);
      row.y = y;
      row.words = words;
      last = sty.ref * row.k;
      y += last * sty.leading;
    }
    return {
      rows: rows,
      h: y - last * sty.leading + sty.capHeight * last / sty.ref
    };
  }

  readonly property var blocks: {
    // Measured again when the faces are there to measure with.
    heavy.height;
    light.height;
    return sty.lines.map(sty.block);
  }

  // Where block `i` sits in the frame of the block before it: to its right and turned a
  // quarter to read upwards, below it, to its right and turned to read downwards, or plainly
  // to its right. No two neighbours overlap, whatever their heights.
  function move(i) {
    var before = sty.blocks[i - 1];
    var kind = (i - 1) % 4;
    if (kind === 0)
      return {
        x: sty.across + sty.gap,
        y: before.h,
        th: -90
      };
    if (kind === 1)
      return {
        x: 0,
        y: before.h + sty.gap,
        th: 0
      };
    if (kind === 2)
      return {
        x: sty.across + sty.gap + sty.blocks[i].h,
        y: 0,
        th: 90
      };
    return {
      x: sty.across + 3 * sty.gap,
      y: 0,
      th: 0
    };
  }

  function turn(th, x, y) {
    var a = th * Math.PI / 180;
    return {
      x: x * Math.cos(a) - y * Math.sin(a),
      y: x * Math.sin(a) + y * Math.cos(a)
    };
  }

  // The world is drawn in the frame of the block before the one in hand (`home`), so only the
  // two either side of it ever need placing, and nothing drifts over a long song. Everything
  // that places a block is told which line is home, and works it out from `cur` itself: a
  // property for it would be a moment behind `cur` as the line changes.
  function homeOf(cur) {
    return Math.max(0, cur - 1);
  }

  function place(i, home) {
    if (i < 0 || i >= sty.blocks.length)
      return null;
    if (i === home)
      return {
        x: 0,
        y: 0,
        th: 0
      };
    if (i === home + 1)
      return sty.move(i);
    if (i === home + 2) {
      var a = sty.move(home + 1);
      var b = sty.move(i);
      var p = sty.turn(a.th, b.x, b.y);
      return {
        x: a.x + p.x,
        y: a.y + p.y,
        th: a.th + b.th
      };
    }
    if (i === home - 1) {
      var m = sty.move(home);
      var q = sty.turn(-m.th, m.x, m.y);
      return {
        x: -q.x,
        y: -q.y,
        th: -m.th
      };
    }
    return null;
  }

  // The camera looking square at block `i`: its middle, the turn that stands it upright, and
  // the pixels a unit takes for it to fill the stage. It closes in a twentieth while the line
  // is sung (`into`, 0..1).
  function pose(i, into, home) {
    var at = sty.place(i, home);
    var h = sty.blocks[i].h;
    var c = sty.turn(at.th, sty.across / 2, h / 2);
    return {
      x: at.x + c.x,
      y: at.y + c.y,
      rot: -at.th,
      zoom: Math.min(0.8 * sty.width / sty.across, 0.7 * sty.height / Math.max(1, h)) * (1 + 0.05 * into)
    };
  }

  // From one pose to the next, `age` seconds into the move. The turn and the zoom trail the
  // travel a little, so the three do not land as one.
  function blend(a, b, age) {
    var p = Kinetic.spring(age, 7.5, 0.86);
    var r = Kinetic.spring(age, 6.5, 0.8);
    var z = Kinetic.spring(age, 6, 0.9);
    return {
      x: Kinetic.lerp(a.x, b.x, p),
      y: Kinetic.lerp(a.y, b.y, p),
      rot: Kinetic.lerp(a.rot, b.rot, r),
      zoom: a.zoom * Math.pow(b.zoom / a.zoom, z)
    };
  }

  readonly property var camera: {
    if (sty.blocks.length === 0 || sty.width <= 0)
      return null;
    var c = Math.max(0, sty.cur);
    var home = sty.homeOf(sty.cur);
    var line = sty.lines[c];
    var to = sty.pose(c, Kinetic.span(line.t, line.out, sty.now), home);
    if (sty.cur < 1 || Theme.reduceMotion)
      return to;
    var start = line.t - sty.lead;
    var from = sty.pose(c - 1, 1, home);
    // A line that came before the camera had settled on the last: it sets out from where it
    // had got to.
    if (c >= 2)
      from = sty.blend(sty.pose(c - 2, 1, home), from, start - (sty.lines[c - 1].t - sty.lead));
    return sty.blend(from, to, sty.now - start);
  }

  // How much of block `i` shows: the line in hand whole, the one before it a ghost, the one
  // before that fading out from under it. A line with a pause after it goes on its own.
  function showing(i) {
    if (sty.cur < 0 || i < 0 || i > sty.cur || i >= sty.lines.length)
      return 0;
    var line = sty.lines[i];
    var held = sty.lines[sty.cur];
    var here = sty.parting(line) ? 1 - Kinetic.smooth(line.out, line.out + 0.6, sty.now) : 1;
    if (i === sty.cur)
      return here;
    var s = Kinetic.smooth(0, 0.5, sty.now - (held.t - sty.lead));
    var ghost = sty.parting(held) ? 1 - Kinetic.smooth(held.out, held.out + 0.6, sty.now) : 1;
    if (i === sty.cur - 1)
      return here * ghost * Kinetic.lerp(1, 0.2, s);
    if (i === sty.cur - 2)
      return here * 0.2 * (1 - s);
    return 0;
  }

  Item {
    id: world

    visible: sty.camera !== null

    transform: Matrix4x4 {
      matrix: {
        var cam = sty.camera;
        if (cam === null)
          return Qt.matrix4x4();
        var r = cam.rot * Math.PI / 180;
        var a = cam.zoom * Math.cos(r);
        var b = cam.zoom * Math.sin(r);
        return Qt.matrix4x4(a, -b, 0, sty.width / 2 - a * cam.x + b * cam.y, b, a, 0, sty.height / 2 - b * cam.x - a * cam.y, 0, 0, 1, 0, 0, 0, 0, 1);
      }
    }

    Repeater {
      model: 4

      Item {
        id: slot

        required property int index

        readonly property int lineIndex: sty.slotLine(index, 4)
        readonly property var line: lineIndex >= 0 ? (sty.lines[lineIndex] || null) : null
        readonly property var block: lineIndex >= 0 && lineIndex < sty.blocks.length ? sty.blocks[lineIndex] : null
        readonly property var at: sty.place(lineIndex, sty.homeOf(sty.cur))

        x: at ? at.x : 0
        y: at ? at.y : 0
        rotation: at ? at.th : 0
        transformOrigin: Item.TopLeft
        opacity: sty.showing(lineIndex)
        visible: at !== null && block !== null && opacity > 0.001

        Repeater {
          model: slot.block ? slot.block.rows : []

          Item {
            id: row

            required property var modelData

            y: modelData.y
            scale: modelData.k
            transformOrigin: Item.TopLeft

            Repeater {
              model: row.modelData.words

              LyricText {
                id: word

                required property var modelData

                readonly property real age: sty.now - modelData.word.t
                // Lands from a little low and a little large, a touch past and back.
                readonly property real land: Theme.reduceMotion ? 1 : Kinetic.outBack(age / 0.36, 0.7)
                readonly property real done: slot.line ? sty.sung(slot.line, modelData.j) : 0

                x: modelData.x
                y: -sty.capTop + (1 - land) * 0.3 * sty.ref
                text: modelData.text
                size: sty.ref
                font.weight: row.modelData.thin ? Font.Light : Font.Black
                tracking: row.modelData.thin ? 0 : -0.02
                color: sty.mix(sty.accent, sty.ink, (sty.now - done) / 0.7)
                scale: 1 + 0.14 * (1 - land)
                opacity: Kinetic.clamp01(age / 0.1)
                visible: age > 0
              }
            }
          }
        }
      }
    }
  }
}
