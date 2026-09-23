import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

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

  // The compact bar's fill runs from the edge, so it has no pill to lead with.
  readonly property real minFill: compact ? 0 : height
  readonly property real displayValue: _previewing ? _previewValue : value
  readonly property real fillWidth: minFill + Math.max(0, Math.min(1, displayValue)) * Math.max(0, width - minFill)
  readonly property real trackHeight: compact ? 4 : height

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

  function queueValue(v) {
    var next = root.clamp(v);
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
    var span = Math.max(1, root.width - root.minFill);
    root.queueValue((x - root.minFill / 2) / span);
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
      root._previewing = false;
  }

  Rectangle {
    y: (parent.height - height) / 2
    width: parent.width
    height: root.trackHeight
    radius: height / 2
    color: root.compact ? Theme.withAlpha(Theme.text, 0.18) : Theme.withAlpha(Theme.highlightLow, 0.9)
  }

  Rectangle {
    id: fill

    y: (parent.height - height) / 2
    width: root.fillWidth
    height: root.trackHeight
    radius: height / 2
    color: root.dimmed ? Theme.withAlpha(Theme.subtle, root.compact ? 0.5 : 0.35) : Theme.accent
    scale: !root.compact && drag.pressed ? Theme.pressScale : 1

    // Smooths a keyboard step or an external change; a drag writes every frame anyway.
    Behavior on width {
      enabled: !drag.pressed

      NumberAnimation {
        duration: Theme.duration(Theme.morphState)
        easing.type: Easing.OutCubic
      }
    }

    Behavior on color {
      Tint {}
    }

    Behavior on scale {
      Morph { duration: Theme.morphState }
    }
  }

  Text {
    x: Theme.controlSliderGlyphLeft
    y: (parent.height - height) / 2
    text: root.glyph
    color: fill.width > x + width && !root.dimmed ? Theme.inkOnAccent : Theme.inkSecondary
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlTileGlyphSize
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
