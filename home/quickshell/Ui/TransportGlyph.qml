import QtQuick
import QtQuick.Shapes

// One UI 9's transport glyphs: solid shapes with softly rounded corners. A triangle is filled
// and stroked in the same colour with round joins, which is what rounds its corners; the
// skip glyphs are that triangle against a rounded bar, mirrored for previous.
Item {
  id: root

  // "play", "pause", "next" or "previous".
  property string kind: "play"
  property color color: "white"

  readonly property bool skip: kind === "next" || kind === "previous"
  readonly property real stroke: 2.4
  readonly property real barWidth: 3

  implicitWidth: skip ? 13 : 15
  implicitHeight: skip ? 13 : 16

  Row {
    anchors.centerIn: parent
    visible: root.kind === "pause"
    spacing: 4

    Repeater {
      model: 2

      Rectangle {
        width: 4.5
        height: root.height - 1
        radius: width / 2
        color: root.color
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.kind !== "pause"
    preferredRendererType: Shape.CurveRenderer

    transform: Scale {
      origin.x: root.width / 2
      xScale: root.kind === "previous" ? -1 : 1
    }

    ShapePath {
      id: triangle

      readonly property real inset: root.stroke / 2
      readonly property real left: inset + (root.skip ? 0 : 1)
      // The skip triangle stops short of the bar, leaving a hairline of air between them.
      readonly property real tip: root.skip ? root.width - root.barWidth - 1.6 - inset : root.width - inset

      fillColor: root.color
      strokeColor: root.color
      strokeWidth: root.stroke
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap

      startX: triangle.left
      startY: triangle.inset

      PathLine {
        x: triangle.left
        y: root.height - triangle.inset
      }

      PathLine {
        x: triangle.tip
        y: root.height / 2
      }

      PathLine {
        x: triangle.left
        y: triangle.inset
      }
    }

    Rectangle {
      x: root.width - width
      width: root.barWidth
      height: root.height
      radius: width / 2
      color: root.color
      visible: root.skip
    }
  }
}
