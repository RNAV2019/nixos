import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// One theme in the carousel: its wallpaper, cropped, with a mini island pill of dots in the
// theme's own colours. Pill and dots come from `colors`, never Theme, so each tile is itself.
Item {
  id: root

  property string source: ""
  property string label: ""
  property var colors: ({})

  // Where the keys are; drives the ring and the tile's size.
  property bool selected: false

  // The theme that is currently up, independent of where the keys are.
  property bool active: false
  signal activated

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.label
  Accessible.description: root.selected ? "Selected theme" : root.active ? "Current theme" : "Theme preview"
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

    // The theme's own ground, so a tile whose wallpaper has not loaded still reads as it.
    Rectangle {
      anchors.fill: parent
      color: root.colors.base !== undefined ? root.colors.base : Theme.overlay
    }

    Image {
      anchors.fill: parent
      source: root.source !== "" ? "file://" + root.source : ""
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

  // The mini island, bottom centre. Fixed size, so it stays put against the bottom edge.
  Rectangle {
    id: pill

    readonly property int count: Theme.themeSwatchRoles.length

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.themePillInset
    width: count * Theme.themeSwatchSize + (count - 1) * Theme.themeSwatchGap + 2 * Theme.themeSwatchPad
    height: Theme.themePillHeight
    radius: height / 2
    color: root.colors.surface !== undefined ? root.colors.surface : Theme.surface

    Row {
      anchors.centerIn: parent
      spacing: Theme.themeSwatchGap

      Repeater {
        model: Theme.themeSwatchRoles

        Rectangle {
          required property string modelData

          width: Theme.themeSwatchSize
          height: width
          radius: width / 2
          color: root.colors[modelData] !== undefined ? root.colors[modelData] : "transparent"
          border.width: 1
          border.color: root.colors.highlightHigh !== undefined ? root.colors.highlightHigh : Theme.highlightHigh
        }
      }
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
}
