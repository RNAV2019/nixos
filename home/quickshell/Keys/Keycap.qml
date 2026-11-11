import QtQuick
import qs.Commons

// One key as it is printed: a lifted cap, square for a single glyph and as wide as its word
// otherwise.
Rectangle {
  id: root

  property string text: ""

  // A lone glyph gets a square whatever its width, so a W and an F make the same cap and the
  // caps before them line up down a column.
  implicitWidth: text.length === 1 ? Theme.keycapHeight : Math.max(Theme.keycapHeight, Math.ceil(label.implicitWidth) + Theme.keycapPad * 2)
  implicitHeight: Theme.keycapHeight
  radius: Theme.keycapRadius
  color: Theme.lift(Theme.liftControl)
  border.width: 1
  border.color: Theme.lift(Theme.liftEdge)

  Text {
    id: label

    anchors.centerIn: parent
    text: root.text
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.keycapLabelSize
    font.weight: Theme.weightMedium
  }
}
