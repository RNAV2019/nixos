import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The wallpaper picker: the island in another shape, growing from the pill's own size,
// radius and centre line. One row of previews, clipped by the panel rather than wrapped.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "wallpaper"
    openWidth: Theme.panelWidth(modelData, Theme.wallpaperWidth)
    openHeight: Theme.wallpaperHeight
    openRadius: Theme.wallpaperRadius

    onOpening: {
      // Open on what is actually up.
      Wallpapers.refresh();
      panel.reseed();
    }

    // Enter applies and leaves. The directory is dimmed and the file name is not, so the name
    // reads at a glance.
    CarouselPanel {
      id: panel

      surface: win
      title: "Wallpaper"
      entries: Wallpapers.entries
      current: Wallpapers.index
      footerPath: Wallpapers.directoryLabel
      footerName: panel.selected >= 0 && panel.selected < panel.count ? panel.entries[panel.selected].name : ""
      emptyHint: "No wallpapers in this folder"

      onChosen: function (index) {
        Wallpapers.apply(panel.entries[index]);
      }

      tile: Component {
        WallpaperTile {
          required property int index
          required property var modelData

          x: panel.carousel.tileX(index)
          y: panel.carousel.tileY(index)
          width: panel.carousel.tileWidth(index)
          height: panel.carousel.tileHeight(index)
          source: "file://" + modelData.real
          glide: panel.carousel.glide
          selected: index === panel.selected
          active: index === Wallpapers.index
          onActivated: panel.choose(index)
        }
      }
    }
  }
}
