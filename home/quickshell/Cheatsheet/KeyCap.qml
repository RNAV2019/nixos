import QtQuick
import qs.Commons
import qs.Ui

// One key on the cheatsheet. A name is a label on a cap as wide as it needs; the four arrows
// and the single characters are drawn square-ish, an arrow as a stroked glyph.
Rectangle {
  id: root

  property string name: ""

  readonly property var arrows: ({
      "←": {
        path: IconPaths.arrowRight,
        flip: true
      },
      "→": {
        path: IconPaths.arrowRight,
        flip: false
      },
      "↑": {
        path: IconPaths.arrowUp,
        flip: false
      },
      "↓": {
        path: IconPaths.arrowDown,
        flip: false
      }
    })
  readonly property var arrow: arrows[name] || null

  // Single glyphs and letters are 24 wide; a longer name is its text and the padding.
  readonly property real squareWidth: 24

  implicitWidth: arrow ? squareWidth : Math.max(squareWidth, label.implicitWidth + Theme.cheatCapPad * 2)
  implicitHeight: Theme.cheatCapHeight
  radius: Theme.cheatCapRadius
  color: Theme.withAlpha(Theme.highlightLow, 0.9)
  border.width: 1
  border.color: Theme.withAlpha(Theme.separator, Theme.powerTileBorderAlpha)

  Text {
    id: label

    anchors.centerIn: parent
    visible: !root.arrow
    text: root.name
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.cheatCapSize
    font.weight: Theme.weightSemi
  }

  StrokeIcon {
    anchors.centerIn: parent
    visible: root.arrow !== null
    path: root.arrow ? root.arrow.path : ""
    size: Theme.cheatCapGlyph
    strokeWidth: 1.75
    color: Theme.inkPrimary
    rotation: root.arrow && root.arrow.flip ? 180 : 0
  }
}
