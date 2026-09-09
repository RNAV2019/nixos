import QtQuick
import qs.Commons

// The control centre's slider. Thick, fully rounded, and dragged anywhere along
// its length rather than by a handle.
//
// The fill is the control: there is no knob, and the glyph rides inside the
// fill at the left, inverting to the surface ink once the fill has reached it.
// The fill never shrinks below its own height, so at zero it is still a circle
// with the glyph in it rather than a sliver.
Item {
  id: root

  property real value: 0
  property string glyph: ""
  // Muted, or otherwise inert. The fill stays where it is and loses its colour,
  // which is what the source does when the sink is muted.
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

    // Only the value animates. A drag writes the value every frame anyway, so
    // this is what smooths a keyboard step or an external change.
    Behavior on width {
      enabled: !drag.pressed

      NumberAnimation {
        duration: Theme.morphSlider
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.morphCurve
      }
    }

    Behavior on color {
      ColorAnimation {
        duration: Theme.morphToggle
      }
    }
  }

  Text {
    x: Theme.controlSliderGlyphLeft
    y: (parent.height - height) / 2
    text: root.glyph
    // The glyph sits on the fill until the fill has retreated past it.
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
