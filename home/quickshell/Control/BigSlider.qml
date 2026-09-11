import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property real value: 0
  property string glyph: ""
  // Muted or otherwise inert: the fill holds its position and loses its colour.
  property bool dimmed: false

  signal moved(real value)

  readonly property real minFill: height
  readonly property real fillWidth: minFill + Math.max(0, Math.min(1, value)) * Math.max(0, width - minFill)

  implicitHeight: Theme.controlSliderHeight

  function setFromX(x) {
    var span = Math.max(1, root.width - root.minFill);
    root.moved(Math.max(0, Math.min(1, (x - root.minFill / 2) / span)));
  }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Theme.withAlpha(Theme.highlightLow, 0.9)
  }

  Rectangle {
    id: fill

    width: root.fillWidth
    height: parent.height
    radius: height / 2
    color: root.dimmed ? Theme.withAlpha(Theme.subtle, 0.35) : Theme.accent
    scale: drag.pressed ? 0.98 : 1

    // Smooths a keyboard step or an external change; a drag writes every frame anyway.
    Behavior on width {
      enabled: !drag.pressed

      NumberAnimation {
        duration: Theme.morphState
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.morphCurve
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
    color: fill.width > x + width && !root.dimmed ? Theme.base : Theme.subtle
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlTileGlyphSize
  }

  MouseArea {
    id: drag

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onPressed: function (event) {
      root.setFromX(event.x);
    }
    onPositionChanged: function (event) {
      if (pressed)
        root.setFromX(event.x);
    }
    onWheel: function (event) {
      root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))));
    }
  }
}
