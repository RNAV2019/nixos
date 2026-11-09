import QtQuick
import qs.Commons

// The clock's roll (Ui/RollingClock.qml) for a Text that already exists: when `label`'s text
// changes, each glyph that changed rolls to its next value on the clock's own timing, and the
// ones that did not stay still. The label remains the resting picture. This draws only while a
// roll runs, as copies of the label cut into one column per glyph, so every glyph sits exactly
// where the label draws it and nothing shifts when the roll starts or lands. The label hides
// itself meanwhile: `visible: !roll.rolling`. Declare this beside the label; it fills it.
//
// The newest text always wins. A change that lands while a roll is running, or straight after
// one (a key held down repeats every 40 ms), is shown at once with no roll, so a reading never
// trails the level it reports.
Item {
  id: root

  required property Text label

  // Off, a change is a cut: the surface is shut, or what the label reports has changed kind.
  property bool live: true
  // How many glyph columns one roll can draw (those of the new text, and the ones leaving); a
  // change that needs more is a cut. 0 for a label that never rolls, which then costs nothing.
  property int capacity: 16
  // The label has no width of its own and is centred on a point (the lock's clock), so the
  // text before sat about the same centre at its own width.
  property bool centred: false
  // A number that fell rolls down, not up.
  property bool directional: false

  readonly property bool rolling: anim.running

  // Left out of a content morph (Ui/MorphScan.js): the label is the part, these are its motion.
  readonly property bool morphIgnore: true

  readonly property real travel: label.font.pixelSize * Theme.clockRollTravel
  // Room past the first and last glyph for ink that overhangs its advance.
  readonly property real overhang: label.font.pixelSize / 2

  // The text the label last showed, and what is on its way: one entry per glyph column.
  // `role` 0 is a glyph that stays, 1 one arriving, 2 one leaving.
  property string shown: ""
  property var columns: []
  property int direction: 1
  property real lastChange: 0

  // Travel and the leaving ink ride `move`; the arriving ink trails on `ink`, as the clock's does.
  property real move: 0
  property real ink: 0

  anchors.fill: label
  visible: rolling

  FontMetrics {
    id: metrics

    font: root.label.font
  }

  // Where glyph `index` of `text` starts, in this item: the line's start by the label's
  // alignment, plus the advance of what comes before the glyph.
  function edge(text, index) {
    var whole = metrics.advanceWidth(text);
    var start = 0;
    if (root.centred || root.label.horizontalAlignment === Text.AlignHCenter)
      start = (root.width - whole) / 2;
    else if (root.label.horizontalAlignment === Text.AlignRight)
      start = root.width - whole;
    return start + metrics.advanceWidth(text.substring(0, index));
  }

  function cut() {
    anim.stop();
    columns = [];
  }

  function changed() {
    var next = label.text;
    var prev = shown;
    var now = Date.now();
    var busy = anim.running || now - lastChange < Theme.clockRollFade;
    shown = next;
    lastChange = now;
    if (!live || capacity === 0 || Theme.reduceMotion || busy || prev === "" || next === "" || prev === next) {
      cut();
      return;
    }

    // A right-aligned reading keeps its last glyphs in place when it gains or loses one
    // (9% to 10%), so glyphs pair from the end there, and from the start otherwise.
    var shift = !centred && label.horizontalAlignment === Text.AlignRight ? next.length - prev.length : 0;
    var cols = [];
    var i, j;
    for (i = 0; i < next.length; i++) {
      j = i - shift;
      cols.push({
        text: next,
        index: i,
        role: j >= 0 && j < prev.length && prev.charAt(j) === next.charAt(i) ? 0 : 1
      });
    }
    for (j = 0; j < prev.length; j++) {
      i = j + shift;
      if (i < 0 || i >= next.length || prev.charAt(j) !== next.charAt(i))
        cols.push({
          text: prev,
          index: j,
          role: 2
        });
    }

    if (cols.length > capacity) {
      cut();
      return;
    }

    var a = parseFloat(prev), b = parseFloat(next);
    direction = directional && !isNaN(a) && !isNaN(b) && b < a ? -1 : 1;
    columns = cols;
    anim.restart();
  }

  onLiveChanged: {
    if (!live)
      cut();
  }

  Component.onCompleted: shown = label.text

  Connections {
    target: root.label

    function onTextChanged() {
      root.changed();
    }
  }

  // The columns are made once and reused, not made per roll, and each holds a glyph until it is
  // given its text. Qt draws a Text whose text has changed since it was first drawn with grey
  // antialiasing, and one drawn for the first time with LCD fringes; the label is the first kind
  // by the time a roll runs, so a copy must be too, or the glyphs' edges would flicker as the
  // roll takes over from the label and hands back.
  Repeater {
    model: root.capacity

    // One glyph's column: a window onto a whole copy of the text, which moves behind it.
    Item {
      id: column

      required property int index

      readonly property var spec: root.columns[index]
      readonly property string text: spec ? spec.text : ""
      readonly property int glyph: spec ? spec.index : 0
      readonly property int role: spec ? spec.role : 0

      readonly property real from: glyph === 0 ? -root.overhang : root.edge(text, glyph)
      readonly property real to: glyph === text.length - 1 ? root.width + root.overhang : root.edge(text, glyph + 1)

      x: from
      y: -root.travel
      width: to - from
      height: root.height + 2 * root.travel
      clip: true
      opacity: role === 0 ? 1 : role === 1 ? root.ink : 1 - root.move
      visible: spec !== undefined

      Text {
        x: (root.centred ? (root.width - width) / 2 : 0) - column.x
        y: root.travel + (column.role === 1 ? root.direction * root.travel * (1 - root.move) : column.role === 2 ? -root.direction * root.travel * root.move : 0)
        width: root.centred ? implicitWidth : root.label.width
        height: root.label.height
        text: column.spec ? column.text : "0"
        color: root.label.color
        font: root.label.font
        renderType: root.label.renderType
        horizontalAlignment: root.label.horizontalAlignment
        verticalAlignment: root.label.verticalAlignment
      }
    }
  }

  ParallelAnimation {
    id: anim

    onFinished: root.columns = []

    NumberAnimation {
      target: root
      property: "move"
      from: 0
      to: 1
      duration: Theme.duration(Theme.clockRoll)
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: root
      property: "ink"
      from: 0
      to: 1
      duration: Theme.duration(Theme.clockRollFade)
      easing.type: Easing.OutCubic
    }
  }
}
