import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// The screen as moving type. Five bands of condensed capitals, stacked floor to ceiling, each
// the line in hand set end to end and sliding, every other band the other way and at its own
// speed. The words are dim until sung, and in every repeat the word in hand is lit, so the
// line fills in across the whole wall at once. Each word knocks every band a step on; a new
// line rolls into the bands one after another, top to bottom.
LyricStyle {
  id: sty

  bloom: 0.5
  bloomKick: 0.45
  aberration: 0.0014
  aberrationKick: 0.005
  punchKick: 0.25
  shakeKick: 0.2
  grain: 0.06
  vignette: 0.5
  ground: 0.8

  // The bands, top to bottom: how tall (in u), how fast and which way (u a second), and whether
  // they are drawn as outlines. The segment's seed turns the wall over so no two segments run
  // the same way.
  readonly property bool flip: Kinetic.hash(seed, 3) > 0.5
  readonly property var bands: [
    {
      h: 15,
      speed: 13,
      hollow: true,
      family: "Bebas Neue"
    },
    {
      h: 23,
      speed: -8,
      hollow: false,
      family: Theme.lyricCondensedFont
    },
    {
      h: 13,
      speed: 21,
      hollow: true,
      family: "Bebas Neue"
    },
    {
      h: 21,
      speed: -11,
      hollow: false,
      family: Theme.lyricCondensedFont
    },
    {
      h: 15,
      speed: 16,
      hollow: true,
      family: "Bebas Neue"
    }
  ]
  readonly property real gap: 1.6 * u
  readonly property real total: bands.reduce(function (s, b) {
    return s + b.h;
  }, 0) * u + gap * (bands.length - 1)

  // One band: the line in hand set end to end as many times as the stage is wide, sliding
  // sideways for ever and lurching on with every word. The whole run is one text with a colour
  // for each word, so a band costs one layout a word however many times the line repeats. On a
  // line change the new run rolls in as the old one rolls out.
  Repeater {
    model: sty.cur >= 0 ? sty.bands.length : 0

    Item {
      id: band

      required property int index

      readonly property var spec: sty.bands[index]
      readonly property int k: index
      readonly property string family: spec.family
      // Drawn as outlines, the sung words filled in.
      readonly property bool hollow: spec.hollow
      // Its drift in u a second; the sign is the way it goes.
      readonly property real speed: spec.speed * (sty.flip ? -1 : 1)
      // Which way the lines roll on a change: 1 up, -1 down.
      readonly property int roll: index % 2 === 0 ? 1 : -1
      // How tall this face's capitals are for its pixel size, so the capitals fill the band.
      readonly property real capRatio: Math.max(0.3, capital.tightBoundingRect.height / 100)
      readonly property real fontSize: height * 0.86 / capRatio

      width: sty.width
      height: spec.h * sty.u
      y: (sty.height - sty.total) / 2 + sty.bands.slice(0, index).reduce(function (s, b) {
        return s + b.h;
      }, 0) * sty.u + index * sty.gap
      clip: true

      TextMetrics {
        id: capital

        font.family: band.family
        font.pixelSize: 100
        text: "H"
      }

      Repeater {
        model: 3

        Item {
          id: slot

          required property int index

          readonly property int lineIndex: sty.slotLine(index, 3)
          readonly property var line: lineIndex >= 0 ? sty.lines[lineIndex] : null
          readonly property real now: sty.now
          // The bands roll one after another, top to bottom, like a board of flaps.
          readonly property real delay: band.k * 0.045
          readonly property real inAt: line ? line.t - sty.lead + delay : 0
          readonly property real outAt: line ? (lineIndex < sty.last ? sty.lines[lineIndex + 1].t - sty.lead : line.out) + delay : 0
          readonly property real rollIn: Kinetic.outQuint(Kinetic.span(inAt, inAt + 0.34, now))
          readonly property real rollOut: Kinetic.outQuint(Kinetic.span(outAt, outAt + 0.34, now))

          // The word in hand: the last to have begun, while it is still being sung.
          readonly property int at: {
            if (!line)
              return -1;
            var j = -1;
            for (var i = 0; i < line.words.length; i++)
              if (line.words[i].t <= now)
                j = i;
            return j;
          }
          readonly property bool lit: at >= 0 && now < Math.min(sty.until(line, at), line.words[at].t + line.words[at].d + 0.35)

          // Every word that has begun has pushed the band a step on, on a spring.
          readonly property real lurch: {
            if (!line)
              return 0;
            var s = 0;
            for (var i = 0; i <= at; i++)
              s += Kinetic.spring(now - line.words[i].t, 16, 0.62);
            return s;
          }
          readonly property real travel: (band.speed * now + Math.sign(band.speed) * 7 * lurch) * sty.u
          readonly property real unit: Math.max(1, measure.implicitWidth)
          readonly property int repeats: Math.ceil(band.width / unit) + 1

          readonly property string sep: "\u2002/\u2002"
          function esc(s) {
            return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
          }

          // One repeat with its colours: sung words in ink, the one in hand in the accent, the
          // rest dim (or not filled at all on a hollow band).
          readonly property string unitMarkup: {
            if (!line)
              return "";
            var ink = sty.ink.toString();
            var lead = sty.accent.toString();
            var dim = band.hollow ? "transparent" : Qt.rgba(sty.ink.r, sty.ink.g, sty.ink.b, 0.16).toString();
            var mark = Qt.rgba(sty.accent2.r, sty.accent2.g, sty.accent2.b, 0.55).toString();
            var out = "";
            for (var i = 0; i < line.words.length; i++) {
              var c = i === at && lit ? lead : i <= at ? ink : dim;
              out += (i > 0 ? " " : "") + "<font color=\"" + c + "\">" + esc(line.words[i].text) + "</font>";
            }
            return out + "<font color=\"" + mark + "\">" + sep + "</font>";
          }

          width: band.width
          height: band.height
          y: band.roll * band.height * ((1 - rollIn) - rollOut)
          visible: line !== null && rollIn > 0 && rollOut < 1

          // The run's length: the same markup, laid out once a word but never drawn.
          LyricText {
            id: measure

            visible: false
            textFormat: Text.StyledText
            text: slot.unitMarkup
            caps: true
            size: band.fontSize
            font.family: band.family
            font.weight: Font.Normal
          }

          LyricText {
            x: -(((slot.travel % slot.unit) + slot.unit) % slot.unit)
            // The capitals sit in the middle of the band.
            y: (band.height + band.capRatio * font.pixelSize) / 2 - baselineOffset
            textFormat: Text.StyledText
            text: slot.visible ? slot.unitMarkup.repeat(slot.repeats) : ""
            caps: true
            size: band.fontSize
            font.family: band.family
            font.weight: Font.Normal
            style: band.hollow ? Text.Outline : Text.Normal
            styleColor: Qt.rgba(sty.ink.r, sty.ink.g, sty.ink.b, 0.3)
          }
        }
      }
    }
  }
}
