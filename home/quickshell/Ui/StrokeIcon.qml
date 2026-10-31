import QtQuick
import QtQuick.Shapes
import qs.Commons

// One icon at `size`, from Commons/IconPaths.qml. Most entries there are Material Symbols
// names, drawn as a filled glyph in Theme.iconFont, the shell's one icon set; the few marks
// Material has no counterpart for (brand logos, board-specific glyphs, the drawn battery
// outline) stay 24-grid SVG path data, stroked with round caps or `filled`. Stroke weight is a
// screen-pixel value and only applies to those.
Item {
  id: root

  // A Material Symbols name, or SVG path data on the 24-unit grid (subpaths are allowed).
  property string path: ""
  property real size: 24
  property color color: "black"
  property real strokeWidth: size * 2 / 24
  property bool filled: false

  // Path data always starts with a moveto; a ligature name never does.
  readonly property bool isGlyph: /^[a-z0-9_]+$/.test(path)

  implicitWidth: size
  implicitHeight: size

  Text {
    anchors.centerIn: parent
    visible: root.isGlyph
    text: root.isGlyph ? root.path : ""
    color: root.color
    font.family: Theme.iconFont
    font.pixelSize: root.size
  }

  Shape {
    width: 24
    height: 24
    visible: !root.isGlyph
    transformOrigin: Item.TopLeft
    scale: root.size / 24
    // The default geometry renderer only antialiases with multisampling, which the
    // island's clipContent layers don't have, so icons inside one came out stair-stepped.
    // The curve renderer computes its own edge coverage, in or out of a layer.
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      // The item's scale carries the geometry; the path is drawn at 24 units.
      fillColor: root.filled ? root.color : "transparent"
      strokeColor: root.filled ? "transparent" : root.color
      strokeWidth: root.strokeWidth * 24 / root.size
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg {
        path: root.isGlyph ? "" : root.path
      }
    }
  }
}
