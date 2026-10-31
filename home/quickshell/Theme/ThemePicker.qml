import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The theme picker: the wallpaper picker's card, a tile per theme. Enter switches to the
// theme under the ring; arrowing does not (a change repaints the desktop). Board 07c.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "theme"
    openWidth: Theme.panelWidth(modelData, Theme.wallpaperWidth)
    openHeight: Theme.wallpaperHeight
    openRadius: Theme.wallpaperRadius

    onOpening: {
      // Open on the theme that is up, with fresh previews.
      Themes.refresh();
      panel.reseed();
    }

    // The footer names the wallpaper folder the chosen theme brings: the parent dimmed, the
    // theme's own folder not, so it reads at a glance.
    CarouselPanel {
      id: panel

      surface: win
      title: "Theme"
      entries: Themes.entries
      current: Themes.index
      footerPath: "~" + Paths.backgroundsDir.substring(Paths.home.length) + "/"
      footerName: panel.selected >= 0 && panel.selected < panel.count ? panel.entries[panel.selected].id + "/" : ""

      onChosen: function (index) {
        Themes.apply(panel.entries[index].id);
      }

      tile: Component {
        ThemeTile {
          required property int index
          required property var modelData

          x: panel.carousel.tileX(index)
          y: panel.carousel.tileY(index)
          width: panel.carousel.tileWidth(index)
          height: panel.carousel.tileHeight(index)
          source: Themes.preview(modelData.id)
          label: modelData.label
          colors: modelData.palette
          glide: panel.carousel.glide
          selected: index === panel.selected
          active: index === Themes.index
          onActivated: panel.choose(index)
        }
      }
    }
  }
}
