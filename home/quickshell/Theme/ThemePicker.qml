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

    // Which theme the ring is on, not the one that is up: that is Themes.index.
    property int selected: 0

    readonly property var entries: Themes.entries
    readonly property int count: entries.length

    // The room the row has.
    readonly property real inner: Theme.wallpaperWidth - 2 * Theme.wallpaperInset

    // The selected tile takes the first width, everything else the last.
    function tileWidth(i) {
      var widths = Theme.wallpaperTileWidths;
      var d = Math.abs(i - win.selected);
      return widths[Math.min(d, widths.length - 1)];
    }

    function tileHeight(i) {
      return Math.round(win.tileWidth(i) / Theme.wallpaperTileAspect);
    }

    function tileX(i) {
      var x = 0;
      for (var j = 0; j < i; j++)
        x += win.tileWidth(j) + Theme.wallpaperTileGap;
      return x;
    }

    readonly property real stripWidth: count > 0 ? win.tileX(count) - Theme.wallpaperTileGap : 0

    // Two themes always fit, so the row is simply centred.
    readonly property real stripX: Theme.wallpaperInset + (inner - stripWidth) / 2

    onOpening: {
      // Open on the theme that is up, with fresh previews.
      Themes.refresh();
      selected = Math.max(0, Themes.index);
    }

    // The row is a ring, as the wallpaper picker's is.
    function step(delta) {
      if (count === 0)
        return;
      selected = ((selected + delta) % count + count) % count;
    }

    function activate() {
      if (selected < 0 || selected >= count)
        return;
      Themes.apply(entries[selected].id);
      hide();
    }

    onKeyPressed: function (event) {
      switch (event.key) {
      case Qt.Key_Escape:
        win.hide();
        break;
      case Qt.Key_Left:
      case Qt.Key_Up:
      case Qt.Key_H:
      case Qt.Key_Backtab:
        win.step(-1);
        break;
      case Qt.Key_Right:
      case Qt.Key_Down:
      case Qt.Key_L:
      case Qt.Key_Tab:
        win.step(1);
        break;
      case Qt.Key_Home:
        win.selected = 0;
        break;
      case Qt.Key_End:
        win.selected = Math.max(0, win.count - 1);
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
      opacity: win.open || win.origin.held ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        enabled: !win.origin.held

        Morph {
          duration: Theme.morphContent
        }
      }

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

      Item {
        id: rail

        x: win.stripX
        y: 0
        width: win.stripWidth
        height: Theme.wallpaperHeight

        Behavior on x {
          enabled: !Theme.reduceMotion

          SurfaceSpring {}
        }

        Repeater {
          model: win.entries

          ThemeTile {
            id: tile

            required property int index
            required property var modelData

            x: win.tileX(index)
            y: Theme.wallpaperRowMid - height / 2
            width: win.tileWidth(index)
            height: win.tileHeight(index)
            source: Themes.preview(modelData.id)
            label: modelData.label
            colors: modelData.palette
            selected: index === win.selected
            active: index === Themes.index
            onActivated: {
              win.selected = tile.index;
              win.activate();
            }

            Behavior on x {
              enabled: !Theme.reduceMotion

              SurfaceSpring {}
            }

            Behavior on width {
              enabled: !Theme.reduceMotion

              SurfaceSpring {}
            }

            Behavior on height {
              enabled: !Theme.reduceMotion

              SurfaceSpring {}
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                tile.activated();
              }
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
        text: "~/Pictures/backgrounds/"
        color: Theme.muted
        font.family: Theme.monoFont
        font.pixelSize: Theme.wallpaperMetaSize
      }

      Text {
        x: directory.x + directory.width
        y: Theme.wallpaperFooterTop
        text: win.selected >= 0 && win.selected < win.count ? win.entries[win.selected].id + "/" : ""
        color: Theme.subtle
        font.family: Theme.monoFont
        font.pixelSize: Theme.wallpaperMetaSize
        font.weight: Font.DemiBold
      }

      Text {
        x: Theme.wallpaperWidth - Theme.wallpaperInset - width
        y: Theme.wallpaperFooterTop
        text: (win.selected + 1) + " / " + win.count + "   ·   Enter to apply"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: Theme.wallpaperMetaSize
      }
    }
  }
}
