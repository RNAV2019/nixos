import QtQuick
import QtQuick.Effects
import qs.Commons

// The shared body of a carousel tile: the picture cropped into a rounded box, the three-state
// ring drawn over it and the active dot. A tile type adds its own extras (the theme's swatch
// pill, say) as plain children; they land above everything here, which is where they belong.
Item {
  id: root

  // Whatever the picker passes; tiles turn it into the image's URL themselves.
  property string source: ""
  // The full URL the picture is loaded from; "" hides the image over the placeholder.
  property string imageSource: ""
  property string kind: "tile"
  property string title: ""

  // Shown under the picture until it loads, so an empty tile still reads as its type.
  property color placeholderColor: Theme.overlay

  // Where the keys are; drives the ring and the tile's size.
  property bool selected: false

  // The entry that is currently up, independent of where the keys are.
  property bool active: false
  signal activated

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.title
  Accessible.description: root.selected ? "Selected " + root.kind : root.active ? "Current " + root.kind : root.kind + " preview"
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.activated()

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
      color: root.placeholderColor
    }

    Image {
      anchors.fill: parent
      source: root.imageSource
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

  // Drawn over the picture rather than around the tile, so the row keeps its pitch. Three
  // weights: full ring (chosen), accent hairline (up), muted hairline (rest).
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
      color: Theme.withAlpha(Theme.canvas, Theme.wallpaperDotHaloAlpha)
    }

    Rectangle {
      anchors.centerIn: parent
      width: Theme.wallpaperDotSize
      height: width
      radius: width / 2
      color: Theme.accent
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
