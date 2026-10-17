import QtQuick
import qs.Commons

// A dashed rounded outline, since Rectangle's pen carries no dash pattern. The two drop
// targets (boards 16e, 16f) are the only dashed edges in the shell.
Canvas {
  id: root

  property color strokeColor: Theme.separator
  property real strokeWidth: 1.5
  property real cornerRadius: 20
  property var dashPattern: [7, 5]

  onPaint: {
    var ctx = getContext("2d");
    ctx.clearRect(0, 0, width, height);
    var inset = strokeWidth / 2;
    var x = inset;
    var y = inset;
    var w = width - strokeWidth;
    var h = height - strokeWidth;
    var r = Math.min(cornerRadius, w / 2, h / 2);

    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.arcTo(x + w, y, x + w, y + r, r);
    ctx.lineTo(x + w, y + h - r);
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.lineTo(x + r, y + h);
    ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();

    ctx.lineWidth = strokeWidth;
    ctx.strokeStyle = strokeColor;
    ctx.setLineDash(dashPattern);
    ctx.stroke();
  }

  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onStrokeColorChanged: requestPaint()
  onStrokeWidthChanged: requestPaint()
  onCornerRadiusChanged: requestPaint()
  onDashPatternChanged: requestPaint()
}
