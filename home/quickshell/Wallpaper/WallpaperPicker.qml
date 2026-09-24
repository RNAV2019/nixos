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

    property bool initializingSelection: false

    readonly property var entries: Wallpapers.entries

    onOpening: {
      // Open on what is actually up.
      initializingSelection = true;
      Wallpapers.refresh();
      if (Wallpapers.index >= 0) {
        carousel.selected = Wallpapers.index;
        initializingSelection = false;
      }
    }

    Connections {
      target: Wallpapers

      function syncSelection() {
        if (!win.initializingSelection || Wallpapers.index < 0)
          return;
        carousel.selected = Wallpapers.index;
        win.initializingSelection = false;
      }

      function onEntriesChanged() {
        syncSelection();
      }

      function onCurrentChanged() {
        syncSelection();
      }
    }

    // Enter applies and leaves. Nothing previews: changing the wallpaper under every arrow
    // key would repaint the desktop repeatedly on the way to a choice.
    function activate() {
      if (carousel.selected < 0 || carousel.selected >= carousel.count)
        return;
      initializingSelection = false;
      Wallpapers.apply(win.entries[carousel.selected]);
      hide();
    }

    // Stepping clears the seeding guard, so a late sync never overwrites the keys.
    function step(delta) {
      initializingSelection = false;
      carousel.step(delta);
    }

    onKeyPressed: function (event) {
      switch (event.key) {
      // h and l alongside the arrows, because a row is a row.
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
        text: "Wallpaper"
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

      // Which wallpaper the ring is on, not the one that is up: that is Wallpapers.index.
      CarouselRow {
        id: carousel

        anchors.fill: parent
        model: win.entries

        tile: Component {
          WallpaperTile {
            required property int index
            required property var modelData

            x: carousel.tileX(index)
            y: Theme.wallpaperRowMid - carousel.tileHeight(index) / 2
            width: carousel.tileWidth(index)
            height: carousel.tileHeight(index)
            source: "file://" + modelData.real
            selected: index === carousel.selected
            active: index === Wallpapers.index
            onActivated: {
              carousel.selected = index;
              win.activate();
            }
          }
        }
      }

      // The directory is dimmed and the file name is not, so the name reads at a glance.
      Text {
        id: directory

        x: Theme.wallpaperInset
        y: Theme.wallpaperFooterTop
        text: Wallpapers.directoryLabel
        color: Theme.muted
        font.family: Theme.monoFont
        font.pixelSize: Theme.wallpaperMetaSize
      }

      Text {
        x: directory.x + directory.width
        y: Theme.wallpaperFooterTop
        text: carousel.selected >= 0 && carousel.selected < carousel.count ? win.entries[carousel.selected].name : ""
        color: Theme.subtle
        font.family: Theme.monoFont
        font.pixelSize: Theme.wallpaperMetaSize
        font.weight: Font.DemiBold
      }

      Text {
        x: Theme.wallpaperWidth - Theme.wallpaperInset - width
        y: Theme.wallpaperFooterTop
        text: carousel.count > 0 ? (carousel.selected + 1) + " / " + carousel.count + "   ·   Enter to apply" : "No wallpapers in this folder"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: Theme.wallpaperMetaSize
      }
    }
  }
}
