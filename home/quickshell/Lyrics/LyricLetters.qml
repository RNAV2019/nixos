import QtQuick
import qs.Commons
import "Kinetic.js" as Kinetic

// A word drawn a letter at a time, each letter where the whole word would have put it (kerning
// and a script's joins included), so the letters can come and go one by one: in order as if
// written, or scattered; dropping out for a frame or two the way an old print's do; and leaving
// one by one at the end. Like everything on the stage it is a function of `now`.
Item {
  id: root

  property string text: ""
  property string family: Theme.lyricDisplayFont
  property int weight: Font.Normal
  property bool italic: false
  property bool caps: false
  property real size: 10
  property color color: Theme.lyricInk

  property real now: 0
  // When the first letter arrives, and how long until the last has.
  property real born: 0
  property real span: 0.2
  // Each letter's own fade up.
  property real rise: 0.09
  // What a letter shows before it has arrived: 0 for not there, more for waiting dim (a line
  // that is all on screen and fills in as it is sung).
  property real floor: 0
  // In order, or each in a place drawn by lot.
  property bool scattered: false
  // When the letters start to go, and over how long, each at its own moment.
  property real gone: Infinity
  property real goneSpan: 0.35
  // How often a letter that is up drops out for a twelfth of a second; 0 for never.
  property real flicker: 0
  // The style's seed and a number of this word's own.
  property int seed: 0
  property int salt: 0

  readonly property string shown: caps ? text.toUpperCase() : text
  readonly property int count: shown.length
  readonly property var pens: {
    var out = [];
    for (var i = 0; i < root.count; i++)
      out.push(root.advance(metrics.font, root.shown.slice(0, i)));
    return out;
  }

  // How wide `s` is set in `face`. The face is handed in, though the metrics already have it,
  // so that a binding which measures reads it and measures again when it changes: a call is not
  // watched, and a word measured before its size was known would keep that width for good.
  function advance(face, s) {
    return metrics.advanceWidth(s);
  }

  implicitWidth: advance(metrics.font, shown)
  implicitHeight: metrics.height

  FontMetrics {
    id: metrics

    font.family: root.family
    font.weight: root.weight
    font.italic: root.italic
    font.pixelSize: Math.max(1, Math.round(root.size))
  }

  Repeater {
    model: root.count

    Text {
      required property int index

      readonly property int place: root.scattered ? Kinetic.scatter(root.seed, root.salt, root.count, index) : index
      readonly property real at: root.born + (root.count > 1 ? place / (root.count - 1) : 0) * root.span
      readonly property real leaveAt: root.gone + Kinetic.hash(root.seed, root.salt + 91, index) * root.goneSpan
      readonly property real up: Kinetic.span(at, at + root.rise, root.now)

      x: index < root.pens.length ? root.pens[index] : 0
      text: root.shown.charAt(index)
      renderType: Text.CurveRendering
      textFormat: Text.PlainText
      color: root.color
      font: metrics.font
      opacity: root.now >= leaveAt ? 0 : (root.floor + (1 - root.floor) * up) * (root.flicker > 0 && up >= 1 ? Kinetic.flick(root.seed, root.salt, index, root.now, root.flicker) : 1)
      visible: opacity > 0
    }
  }
}
