import QtQuick
import qs.Commons

// One row of tiles asking "which of these". The power menu, the profiles card and the
// recorder picker all draw this grid.
Item {
  id: root

  // Entries of { glyph, label }, rebuilt by the caller when a label changes.
  property var model: []

  // The tile the keyboard is on and the tile that is filled are not the same thing.
  property int currentIndex: 0
  property int activeIndex: -1
  property int inset: Theme.powerInset
  property string activeLabel: ""

  // Love where the machine's whole stance changes, accent where it is one pick of three.
  property color activeColor: Theme.accent

  // The power menu sets this: an armed tile must not wear the ring a selected one wears.
  property bool activeIsCommitting: false

  signal activated(int index)
  signal entered(int index)

  readonly property int count: model.length

  // The grid's own width, which is what the surfaces around it open to.
  readonly property int contentWidth: root.inset * 2 + count * Theme.powerTileWidth + Math.max(0, count - 1) * Theme.powerTileGap

  function tileX(i) {
    return root.inset + i * (Theme.powerTileWidth + Theme.powerTileGap);
  }

  implicitWidth: contentWidth
  implicitHeight: Theme.powerTileTop * 2 + Theme.powerTileHeight

  Repeater {
    model: root.model

    Tile {
      id: tile

      required property int index
      required property var modelData

      kind: Tile.Choice
      x: root.tileX(index)
      y: Theme.powerTileTop
      active: root.activeIndex === tile.index
      current: root.currentIndex === tile.index
      activeColor: root.activeColor
      activeIsCommitting: root.activeIsCommitting
      glyph: tile.modelData.glyph
      label: tile.active && root.activeLabel !== "" ? root.activeLabel : tile.modelData.label
      accessibleName: tile.modelData.label
      onClicked: root.activated(tile.index)
      // Hovering moves the keyboard's place too, so the hovered tile is the one Return fires.
      onHoveredChanged: if (tile.hovered)
        root.entered(tile.index)
    }
  }
}
