import QtQuick
import QtQuick.Shapes

// One character of the lock's big clock as an outline, filled, hung from the top of its own ink
// at its pen position (see the roll in LockView.qml's clockBox). A turning one is squashed to
// `squash` of its height about the row `anchor` (its own coordinates) and moved by `shift`.
//
// A file of its own, not an inline component of LockView.qml: a running shell that reloads its
// configuration does not take an inline component added to a file it has already loaded
// ("RollGlyph is not a type"), and the lock must never be what a reload fails on.
Shape {
  property alias glyph: glyphText.text
  property alias face: glyphText.font
  property real squash: 1
  property real anchor: 0
  property real shift: 0

  preferredRendererType: Shape.GeometryRenderer
  visible: squash > 0

  transform: [
    Scale {
      origin.y: anchor
      yScale: squash
    },
    Translate {
      y: shift
    }
  ]

  ShapePath {
    fillColor: "white"
    strokeColor: "transparent"
    strokeWidth: -1

    PathText {
      id: glyphText
    }
  }
}
