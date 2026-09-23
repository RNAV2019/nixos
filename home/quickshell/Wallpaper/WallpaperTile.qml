import QtQuick
import qs.Commons
import qs.Ui

// One preview in the carousel. The picture is cropped into a fixed box rather than
// fitted, so the row stays a row of equal rectangles.
TileBase {
  id: root

  property string source: ""

  kind: "wallpaper"
  title: root.source
  imageSource: root.source
}
