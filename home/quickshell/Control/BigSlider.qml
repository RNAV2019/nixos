import QtQuick
import qs.Commons
import qs.Ui

// The control centre's slider: a pill (or, `compact`, a thin bar) whose fill is the value. It
// follows the pointer exactly while dragged; a wheel or key step, or a change from outside, moves
// the fill on a spring. Held, the bar grows a few pixels taller and springs back when let go; it
// is not scaled, so the fill never leaves the bar's edge.
Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "slider"
  property string morphKey: ""
  property var morphSlot: undefined

  property real value: 0
  property string glyph: ""
  property string accessibleName: ""
  // Muted or otherwise inert: the fill holds its position and loses its colour.
  property bool dimmed: false
  // A thin bar instead of a pill, for the per-application stream rows.
  property bool compact: false

  signal moved(real value)

  // Keep the thumb responsive to the pointer while limiting how often the backing service or
  // PipeWire property is written.
  property real _previewValue: 0
  property real _pendingValue: 0
  property bool _previewing: false
  property bool _hasPendingValue: false
  property bool _interactionActive: false

  // The compact bar's fill runs from the edge, so it has no pill to lead with. `restFill` is the
  // pill at rest, which the pointer is measured against; `minFill` grows with a held bar so the
  // fill's end stays round.
  readonly property real restFill: compact ? 0 : height
  readonly property real minFill: compact ? 0 : trackHeight
  readonly property real displayValue: _previewing ? _previewValue : value
  readonly property real fillWidth: minFill + Math.max(0, Math.min(1, shown.value)) * Math.max(0, width - minFill)
  readonly property real trackHeight: (compact ? 4 : height) + grow.value
  readonly property string who: Theme.motionLog ? root.toString().replace(/^.*\(0x([0-9a-f]+)\).*$/, "$1") : ""

  implicitHeight: Theme.controlSliderHeight

  activeFocusOnTab: true

  Accessible.role: Accessible.Slider
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : "Slider"
  Accessible.description: Math.round(Math.max(0, Math.min(1, root.displayValue)) * 100) + "%"
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onIncreaseAction: root.queueValue(root.displayValue + Theme.sliderStep)
  Accessible.onDecreaseAction: root.queueValue(root.displayValue - Theme.sliderStep)

  function clamp(v) {
    return Math.max(0, Math.min(1, v));
  }

  // Every applied value sits on the key-step ladder, so drags, the wheel and the keys
  // all land on the same multiples of 5 and the backing service never sees between them.
  function quantize(v) {
    return Math.round(root.clamp(v) / Theme.sliderStep) * Theme.sliderStep;
  }

  function queueValue(v) {
    var next = root.quantize(v);
    root._previewValue = next;
    root._previewing = true;
    if (root._hasPendingValue && Math.abs(root._pendingValue - next) < 0.0005)
      return;
    root._pendingValue = next;
    root._hasPendingValue = true;
    emitMove.restart();
  }

  function flushValue() {
    if (!root._hasPendingValue)
      return;
    emitMove.stop();
    var next = root._pendingValue;
    root._hasPendingValue = false;
    root.moved(next);
  }

  function beginInteraction() {
    root._interactionActive = true;
    previewExpiry.stop();
  }

  function finishInteraction() {
    root._interactionActive = false;
    root.flushValue();
    previewExpiry.restart();
  }

  function setFromX(x) {
    var span = Math.max(1, root.width - root.restFill);
    root.queueValue((x - root.restFill / 2) / span);
  }

  onValueChanged: {
    if (!root._interactionActive && root._previewing && Math.abs(root.clamp(root.value) - root._previewValue) < 0.01) {
      root._previewing = false;
      previewExpiry.stop();
    }
  }

  Timer {
    id: emitMove

    interval: 16
    repeat: false
    onTriggered: root.flushValue()
  }

  Timer {
    id: previewExpiry

    interval: 250
    repeat: false
    onTriggered: if (!root._interactionActive)
      root._previewing = false
  }

  // Where the fill is drawn, 0..1: the value itself while the pointer has it, and a spring toward
  // it for a wheel or key step or a change from outside. Over the value, not over pixels, so a
  // slider that is laid out late does not sweep into place.
  ProgressSpring {
    id: shown

    target: Math.max(0, Math.min(1, root.displayValue))
    omega: Theme.microOmega
    animate: !root._interactionActive
    label: root.who !== "" ? "slider." + root.who + ".fill" : ""
  }

  // The press: the bar grows about its middle while held. The thin bar grows by less.
  MorphSpring {
    id: grow

    target: drag.pressed ? Math.min(Theme.sliderPressGrow, root.compact ? 2 : Infinity) : 0
    omega: drag.pressed ? Theme.pressOmega : Theme.pressReleaseOmega
    epsilon: 0.05
    label: root.who !== "" ? "slider." + root.who + ".grow" : ""
  }

  LevelTrack {
    id: track

    y: (parent.height - height) / 2
    width: parent.width
    height: root.trackHeight
    value: root.width > 0 ? root.fillWidth / root.width : 0
    fillColor: root.dimmed ? Theme.withAlpha(Theme.subtle, root.compact ? 0.5 : 0.35) : Theme.accent
    // The spring above does the smoothing; the track's own timed ease would trail it.
    fillDuration: 0

    Behavior on fillColor {
      Tint {}
    }
  }

  StrokeIcon {
    x: Theme.controlSliderGlyphLeft
    y: (parent.height - height) / 2
    visible: root.glyph !== ""
    size: Theme.controlTileGlyphSize
    path: root.glyph
    color: track.fill.width > x + width && !root.dimmed ? Theme.inkOnAccent : Theme.inkSecondary
  }

  MouseArea {
    id: drag

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onPressed: function (event) {
      root.forceActiveFocus();
      root.beginInteraction();
      root.setFromX(event.x);
    }
    onPositionChanged: function (event) {
      if (pressed)
        root.setFromX(event.x);
    }
    onReleased: root.finishInteraction()
    onCanceled: root.finishInteraction()
    onWheel: function (event) {
      root.forceActiveFocus();
      root.queueValue(root.displayValue + (event.angleDelta.y > 0 ? Theme.sliderStep : -Theme.sliderStep));
      previewExpiry.restart();
      event.accepted = true;
    }
  }

  Keys.onPressed: function (event) {
    var next = root.displayValue;
    var absolute = false;
    switch (event.key) {
    case Qt.Key_Left:
    case Qt.Key_Down:
      next -= Theme.sliderStep;
      break;
    case Qt.Key_Right:
    case Qt.Key_Up:
      next += Theme.sliderStep;
      break;
    case Qt.Key_PageDown:
      next -= 0.1;
      break;
    case Qt.Key_PageUp:
      next += 0.1;
      break;
    case Qt.Key_Home:
      next = 0;
      absolute = true;
      break;
    case Qt.Key_End:
      next = 1;
      absolute = true;
      break;
    default:
      return;
    }
    root.queueValue(absolute ? next : root.clamp(next));
    previewExpiry.restart();
    event.accepted = true;
  }
}
