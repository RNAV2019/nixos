import QtQuick
import QtQuick.Shapes

// The design's icons (boards 16a-16g) are 24-grid round-capped stroke marks - and the
// shell's font glyphs are filled, so they cannot match them. One shape renderer covers
// both the strokes and the few filled marks (the Apple logo). Weight is a screen-pixel
// value, since the design tunes it per size.
Item {
  id: root

  // SVG path data on the 24-unit grid; subpaths are allowed.
  property string path: ""
  property real size: 24
  property color color: "black"
  property real strokeWidth: size * 2 / 24
  property bool filled: false

  implicitWidth: size
  implicitHeight: size

  Shape {
    width: 24
    height: 24
    transformOrigin: Item.TopLeft
    scale: root.size / 24
    antialiasing: true

    ShapePath {
      // The item's scale carries the geometry; the path is drawn at 24 units.
      fillColor: root.filled ? root.color : "transparent"
      strokeColor: root.filled ? "transparent" : root.color
      strokeWidth: root.strokeWidth * 24 / root.size
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg {
        path: root.path
      }
    }
  }
}
