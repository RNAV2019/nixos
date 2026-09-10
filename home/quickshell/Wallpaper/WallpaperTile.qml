import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// One preview in the carousel.
//
// The tile is a fixed box that the picture is cropped into rather than fitted
// to, so a wallpaper of any shape fills it and the row stays a row of equal
// rectangles. Losing a little off the top and bottom of a 16:10 picture in a
// 16:9 box is the right trade: a fitted preview would leave panel background
// inside the tile, and the tile's shape is what the eye is scanning.
Item {
  id: root

  property string source: ""

  // Where the keys are. Carried by the ring and by the tile's size.
  property bool selected: false

  // The wallpaper that is currently up. Independent of the above: it is still
  // the one on screen while the ring is somewhere else, and the row would
  // otherwise lose track of it the moment the first arrow is pressed.
  property bool active: false

  // Corner radius is not scaled with the tile. The tiles change size as the
  // selection moves past them, and a radius that grew with them would read as
  // the corners breathing.
  readonly property real cornerRadius: Theme.wallpaperTileRadius

  Item {
    id: content

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    // Something to look at while the picture decodes, and what a wallpaper
    // that has gone missing leaves behind.
    Rectangle {
      anchors.fill: parent
      color: Theme.overlay
    }

    Image {
      id: picture

      anchors.fill: parent
      source: root.source
      fillMode: Image.PreserveAspectCrop
      // Decoded at about twice the tile, which is enough for the tile to grow
      // into its selected size without softening and cheap enough to hold a
      // row of them.
      sourceSize.width: Theme.wallpaperTileWidths[0] * 2
      asynchronous: true
      cache: true
      visible: status === Image.Ready
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: root.cornerRadius
      color: "black"
    }
  }

  // The ring is drawn over the picture rather than around the tile, so the row
  // keeps its pitch whether or not a tile is carrying one.
  //
  // Three weights, in the order they matter: the full ring for the tile being
  // chosen, a hairline of the same accent for the one that is up, and the
  // muted hairline for the rest. The active tile borrows the accent rather
  // than a second colour because it is the same fact at a lower volume, and a
  // row that answered "which is up" in another hue would read as two rows.
  Rectangle {
    anchors.fill: parent
    radius: root.cornerRadius
    color: "transparent"
    border.width: root.selected ? Theme.wallpaperSelectedBorder : 1
    border.color: root.selected ? Theme.accent : root.active ? Theme.withAlpha(Theme.accent, Theme.wallpaperActiveBorderAlpha) : Theme.withAlpha(Theme.highlightMed, Theme.wallpaperTileBorderAlpha)

    Behavior on border.color {
      Tint {}
    }
  }

  // The one mark that survives a screenshot in greyscale, and the only thing
  // in the row that is unambiguously about the wallpaper on screen rather than
  // about where the keys have got to.
  Item {
    x: parent.width - width - Theme.wallpaperDotInset
    y: Theme.wallpaperDotInset
    width: Theme.wallpaperDotHalo
    height: width
    visible: root.active

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Theme.withAlpha(Theme.base, Theme.wallpaperDotHaloAlpha)
    }

    Rectangle {
      anchors.centerIn: parent
      width: Theme.wallpaperDotSize
      height: width
      radius: width / 2
      color: Theme.accent
    }
  }
}
