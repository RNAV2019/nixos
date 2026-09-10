import QtQuick
import qs.Commons
import qs.Ui

// One quick-settings tile, and the control centre's split tap target.
//
// The source shell puts two actions on every tile: the icon badge toggles the
// thing on or off, and the rest of the tile opens that thing's sub-view. A tile
// with nothing to open - peace, night light - gives its whole width to the
// toggle instead, so no part of it is dead.
//
// Accent fill is the only state indicator. There is no separate switch, and the
// label and the badge invert with the fill rather than sitting on it, which is
// why every colour here is chosen against `on` rather than against the surface.
Rectangle {
  id: root

  property string label: ""
  property string sublabel: ""
  property string glyph: ""
  property bool on: false
  property bool opensView: false
  property bool keyFocused: false

  signal toggled
  signal opened

  readonly property bool hovered: badgeHover.containsMouse || bodyHover.containsMouse
  readonly property bool pressed: badgeHover.pressed || bodyHover.pressed

  height: Theme.controlTileHeight
  radius: Theme.controlTileRadius

  color: {
    if (on)
      return hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent;
    return Theme.withAlpha(hovered ? Theme.highlightMed : Theme.highlightLow, 0.9);
  }

  border.width: on ? 0 : 1
  border.color: root.keyFocused ? Theme.accent : Theme.withAlpha(Theme.highlightMed, 0.7)
  scale: pressed ? 0.97 : 1

  Behavior on color {
    Tint {}
  }

  Behavior on scale {
    Morph { duration: Theme.morphState }
  }

  Rectangle {
    id: badge

    x: Theme.controlTileBadgeLeft
    y: (parent.height - height) / 2
    width: Theme.controlTileBadge
    height: Theme.controlTileBadge
    radius: height / 2
    color: root.on ? Theme.withAlpha(Theme.base, badgeHover.containsMouse ? 0.28 : 0.16) : Theme.withAlpha(Theme.text, badgeHover.containsMouse ? 0.14 : 0.07)

    Behavior on color {
      Tint {}
    }

    Text {
      anchors.centerIn: parent
      text: root.glyph
      color: root.on ? Theme.base : Theme.subtle
      font.family: Theme.iconFont
      font.pixelSize: Theme.controlTileGlyphSize
    }
  }

  Text {
    id: name

    x: Theme.controlTileTextLeft
    y: 12
    width: Math.max(0, root.width - x - 10)
    text: root.label
    color: root.on ? Theme.base : Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    x: name.x
    y: 30
    width: name.width
    text: root.sublabel
    color: root.on ? Theme.withAlpha(Theme.base, 0.72) : Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileSubSize
    elide: Text.ElideRight
  }

  // The badge's own target is the badge plus the gutter around it, so the split
  // falls where the text begins rather than on the drawn circle's edge.
  MouseArea {
    id: badgeHover

    x: 0
    y: 0
    width: Theme.controlTileTextLeft
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }

  MouseArea {
    id: bodyHover

    x: badgeHover.width
    y: 0
    width: Math.max(0, parent.width - x)
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.opensView ? root.opened() : root.toggled()
  }
}
