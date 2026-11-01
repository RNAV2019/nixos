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
  // The curve renderer (see the Shape below) draws nothing at all on the lock surface and its
  // preview, for a reason not pinned down: the lock's path icons opt back into the geometry
  // renderer, which draws there as it did before the switch.
  property bool curve: true
  // Keep a Material glyph's vertical centring off the pixel grid, which anchors.centerIn rounds
  // to; the horizontal one is still rounded.
  property bool fineY: false
  // Centre a Material glyph on its ink rather than its advance, for glyphs that pad or overhang
  // their cell (the volume ladder pads two steps with a trailing space).
  property bool inkCentred: false

  // Path data always starts with a moveto; a ligature name never does.
  readonly property bool isGlyph: /^[a-z0-9_]+$/.test(path)

  implicitWidth: size
  implicitHeight: size

  TextMetrics {
    id: ink

    font: glyphText.font
    text: glyphText.text
  }

  Text {
    id: glyphText

    anchors.centerIn: root.inkCentred || root.fineY ? undefined : parent
    anchors.horizontalCenter: root.fineY && !root.inkCentred ? parent.horizontalCenter : undefined
    visible: root.isGlyph
    text: root.isGlyph ? root.path : ""
    color: root.color
    font.family: Theme.iconFont
    font.pixelSize: root.size
  }

  Binding {
    target: glyphText
    property: "x"
    value: (root.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x
    when: root.inkCentred
  }

  Binding {
    target: glyphText
    property: "y"
    value: (root.height - glyphText.height) / 2
    when: root.inkCentred || root.fineY
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
    preferredRendererType: root.curve ? Shape.CurveRenderer : Shape.GeometryRenderer
    antialiasing: !root.curve

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
