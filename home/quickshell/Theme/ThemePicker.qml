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

    readonly property var entries: Themes.entries

    onOpening: {
      // Open on the theme that is up, with fresh previews.
      Themes.refresh();
      carousel.selected = Math.max(0, Themes.index);
    }

    function activate() {
      if (carousel.selected < 0 || carousel.selected >= carousel.count)
        return;
      Themes.apply(win.entries[carousel.selected].id);
      hide();
    }

    onKeyPressed: function (event) {
      switch (event.key) {
      case Qt.Key_Left:
      case Qt.Key_Up:
      case Qt.Key_H:
      case Qt.Key_Backtab:
        carousel.step(-1);
        break;
      case Qt.Key_Right:
      case Qt.Key_Down:
      case Qt.Key_L:
      case Qt.Key_Tab:
        carousel.step(1);
        break;
      case Qt.Key_Home:
        carousel.selected = 0;
        break;
      case Qt.Key_End:
        carousel.selected = Math.max(0, carousel.count - 1);
        break;
      case Qt.Key_Return:
      case Qt.Key_Enter:
        win.activate();
        break;
      default:
        return;
      }
      event.accepted = true;
    }

    Item {
      id: body

      anchors.fill: parent

      Text {
        x: Theme.wallpaperInset
        y: Theme.wallpaperTitleTop
        text: "Theme"
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.wallpaperTitleSize
        font.weight: Font.Medium
      }

      Text {
        x: Theme.wallpaperWidth - Theme.wallpaperInset - width
        y: Theme.wallpaperMetaTop
        text: Theme.paletteName
        color: Theme.subtle
        font.family: Theme.uiFont
        font.pixelSize: Theme.wallpaperMetaSize
      }

      // Which theme the ring is on, not the one that is up: that is Themes.index.
      CarouselRow {
        id: carousel

        anchors.fill: parent
        model: win.entries

        tile: Component {
          ThemeTile {
            required property int index
            required property var modelData

            x: carousel.tileX(index)
            width: carousel.tileWidth(index)
            height: carousel.tileHeight(index)
            source: Themes.preview(modelData.id)
            label: modelData.label
            colors: modelData.palette
            selected: index === carousel.selected
            active: index === Themes.index
            onActivated: {
              carousel.selected = index;
              win.activate();
            }
          }
        }
      }

      // The footer names the wallpaper folder the chosen theme brings: the parent dimmed,
      // the theme's own folder not, so it reads at a glance.
      Text {
        id: directory

        x: Theme.wallpaperInset
        y: Theme.wallpaperFooterTop
        text: "~" + Paths.backgroundsDir.substring(Paths.home.length) + "/"
        color: Theme.muted
        font.family: Theme.monoFont
        font.pixelSize: Theme.wallpaperMetaSize
      }

      Text {
        x: directory.x + directory.width
        y: Theme.wallpaperFooterTop
        text: carousel.selected >= 0 && carousel.selected < carousel.count ? win.entries[carousel.selected].id + "/" : ""
        color: Theme.subtle
        font.family: Theme.monoFont
        font.pixelSize: Theme.wallpaperMetaSize
        font.weight: Font.DemiBold
      }

      Text {
        x: Theme.wallpaperWidth - Theme.wallpaperInset - width
        y: Theme.wallpaperFooterTop
        text: (carousel.selected + 1) + " / " + carousel.count + "   ·   Enter to apply"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: Theme.wallpaperMetaSize
      }
    }
  }
}
