import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// One preview in the carousel. The picture is cropped into a fixed box rather than
// fitted to it, so the row stays a row of equal rectangles.
Item {
  id: root

  property string source: ""

  // Where the keys are. Carried by the ring and by the tile's size.
  property bool selected: false

  // The wallpaper that is currently up, independent of where the keys are.
  property bool active: false

  // Not scaled with the tile: a radius that grew would read as the corners breathing.
  readonly property real cornerRadius: Theme.wallpaperTileRadius

  Item {
    id: content

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.overlay
    }

    Image {
      id: picture

      anchors.fill: parent
      source: root.source
      fillMode: Image.PreserveAspectCrop
      // Decoded at about twice the tile, so it grows into its selected size unsoftened.
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

  // Drawn over the picture rather than around the tile, so the row keeps its pitch.
  // Three weights: the full ring for the tile being chosen, an accent hairline for the
  // one that is up, and a muted hairline for the rest.
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
