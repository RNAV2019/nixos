import QtQuick
import qs.Commons
import qs.Ui

// One reading in the phone panel's top row (board "Phone panel": Battery, Mobile, Wi-Fi). It
// reports and takes no press, so it is not a Tile: a flat ground with no outline, a bare glyph
// beside the label, the value under them, and for the battery a level bar along the foot. The
// glyph is placed by its ink, not its box, so the value's left edge below runs straight up
// through it; the label follows the ink.
Item {
  id: root

  property string label: ""
  property string value: ""
  // A Material Symbols name (StrokeIcon).
  property string glyph: ""
  property color glyphColor: Theme.accent
  property color valueColor: Theme.withAlpha(Theme.inkPrimary, Theme.phoneReadingValueAlpha)
  // 0..1 draws the bar at the foot; below zero there is no level to show.
  property real level: -1
  property color levelColor: Theme.accent

  readonly property real pad: Theme.controlTileStackedPad
  readonly property real glyphSize: Theme.controlTileGlyphSize
  // The glyph's ink within its box, and where it ends.
  readonly property real inkLeft: (glyphSize - ink.advanceWidth) / 2 + ink.tightBoundingRect.x
  readonly property real inkWidth: ink.tightBoundingRect.width

  implicitHeight: Theme.phoneReadingHeight

  Accessible.role: Accessible.StaticText
  Accessible.name: root.label
  Accessible.description: root.value

  TextMetrics {
    id: ink

    font.family: Theme.iconFont
    font.pixelSize: root.glyphSize
    text: root.glyph
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.controlTileStackedRadius
    color: Theme.lift(Theme.liftTile)

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Theme.withAlpha(Theme.inkPrimary, Theme.phoneReadingWashAlpha)
    }
  }

  StrokeIcon {
    id: icon

    x: root.pad - root.inkLeft
    y: Theme.phoneReadingGlyphTop
    size: root.glyphSize
    strokeWidth: 1.75
    path: root.glyph
    color: root.glyphColor
  }

  Text {
    x: root.pad + root.inkWidth + Theme.phoneReadingGlyphGap
    y: icon.y + (icon.height - height) / 2
    width: Math.max(0, root.width - x - Theme.controlTileStackedTextSlack)
    text: root.label
    elide: Text.ElideRight
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize
    font.weight: Theme.weightMedium
  }

  Text {
    x: root.pad
    y: Theme.phoneReadingValueTop
    width: Math.max(0, root.width - x - Theme.controlTileStackedTextSlack)
    text: root.value
    elide: Text.ElideRight
    color: root.valueColor
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileSubSize
  }

  LevelTrack {
    x: root.pad
    y: root.height - root.pad - height
    width: root.width - 2 * root.pad
    height: Theme.phoneReadingBarHeight
    visible: root.level >= 0
    color: Theme.highlightMed
    fillColor: root.levelColor
    value: root.level
  }
}
