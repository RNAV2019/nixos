import QtQuick
import QtQuick.Shapes
import qs.Commons

// A dashed rounded outline, since Rectangle's pen carries no dash pattern. The two drop
// targets (boards 16e, 16f) are the only dashed edges in the shell. A Shape on the curve renderer,
// so it is drawn on the GPU like everything else: it was a Canvas, the one thing in the shell
// painted on the CPU and uploaded.
Shape {
  id: root

  property color strokeColor: Theme.separator
  property real strokeWidth: 1.5
  property real cornerRadius: 20
  // Dash and gap, in px.
  property var dashPattern: [7, 5]

  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    strokeColor: root.strokeColor
    strokeWidth: root.strokeWidth
    fillColor: "transparent"
    capStyle: ShapePath.FlatCap
    strokeStyle: ShapePath.DashLine
    // ShapePath counts a dash in stroke widths.
    dashPattern: root.dashPattern.map(function (d) {
      return d / Math.max(0.1, root.strokeWidth);
    })

    PathRectangle {
      x: root.strokeWidth / 2
      y: root.strokeWidth / 2
      width: Math.max(0, root.width - root.strokeWidth)
      height: Math.max(0, root.height - root.strokeWidth)
      radius: Math.max(0, Math.min(root.cornerRadius, width / 2, height / 2))
    }
  }
}
