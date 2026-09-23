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

    // Which wallpaper the ring is on, not the one that is up: that is Wallpapers.index.
    property int selected: 0
    property bool initializingSelection: false

    readonly property var entries: Wallpapers.entries
    readonly property int count: entries.length

    // The room the row has, and the room it wants.
    readonly property real inner: Theme.wallpaperWidth - 2 * Theme.wallpaperInset

    // The selected tile takes the first width, everything else the last, indexed by
    // distance from the selection and clamped to its end; see the token note.
    function tileWidth(i) {
      var widths = Theme.wallpaperTileWidths;
      var d = Math.abs(i - win.selected);
      return widths[Math.min(d, widths.length - 1)];
    }

    function tileHeight(i) {
      return Math.round(win.tileWidth(i) / Theme.wallpaperTileAspect);
    }

    // A tile's left edge is the sum before it, so selecting right pushes the row left.
    function tileX(i) {
      var x = 0;
      for (var j = 0; j < i; j++)
        x += win.tileWidth(j) + Theme.wallpaperTileGap;
      return x;
    }

    readonly property real stripWidth: count > 0 ? win.tileX(count) - Theme.wallpaperTileGap : 0

    // A fitting row is centred; otherwise the selection is pulled to the centre line,
    // then clamped so neither end passes the inset.
    readonly property real stripX: {
      if (stripWidth <= inner)
        return Theme.wallpaperInset + (inner - stripWidth) / 2;

      var wanted = Theme.wallpaperWidth / 2 - (win.tileX(win.selected) + win.tileWidth(win.selected) / 2);
      var furthest = Theme.wallpaperWidth - Theme.wallpaperInset - stripWidth;
      return Math.max(furthest, Math.min(Theme.wallpaperInset, wanted));
    }

    onOpening: {
      // Open on what is actually up.
      initializingSelection = true;
      Wallpapers.refresh();
      if (Wallpapers.index >= 0) {
        selected = Wallpapers.index;
        initializingSelection = false;
      }
    }

    Connections {
      target: Wallpapers

      function syncSelection() {
        if (!win.initializingSelection || Wallpapers.index < 0)
          return;
        win.selected = Wallpapers.index;
        win.initializingSelection = false;
      }

      function onEntriesChanged() {
        syncSelection();
      }

      function onCurrentChanged() {
        syncSelection();
      }
    }

    // The row is a ring: stepping past either end comes out at the other. The modulo
    // survives a negative delta, since JavaScript's % keeps the left sign.
    function step(delta) {
      if (count === 0)
        return;
      initializingSelection = false;
      selected = ((selected + delta) % count + count) % count;
    }

    // Enter applies and leaves. Nothing previews: changing the wallpaper under every arrow
    // key would repaint the desktop repeatedly on the way to a choice.
    function activate() {
      if (selected < 0 || selected >= count)
        return;
      initializingSelection = false;
      Wallpapers.apply(entries[selected]);
      hide();
    }

    onKeyPressed: function (event) {
      switch (event.key) {
      case Qt.Key_Escape:
        win.hide();
        break;
      // h and l alongside the arrows, because a row is a row.
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

      // Clipped to the panel, not the inset, so a long row is cut by the panel's own edge
      // and reads as running on past it.
      Item {
        id: strip

        x: 0
        y: 0
        width: Theme.wallpaperWidth
        height: Theme.wallpaperHeight
        clip: true

        Item {
          id: rail

          x: win.stripX
          y: 0
          width: win.stripWidth
          height: parent.height

          Behavior on x {
            enabled: !Theme.reduceMotion

            SurfaceSpring {}
          }

          Repeater {
            model: win.entries

            WallpaperTile {
              id: tile

              required property int index
              required property var modelData

              x: win.tileX(index)
              y: Theme.wallpaperRowMid - height / 2
              width: win.tileWidth(index)
              height: win.tileHeight(index)
              source: "file://" + modelData.real
              selected: index === win.selected
              active: index === Wallpapers.index
              onActivated: {
                win.selected = tile.index;
                win.activate();
              }

              // Every tile travels and resizes on one curve, keeping gaps constant: a sum of
              // identical eases is the same ease of the sum.
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
        text: win.selected >= 0 && win.selected < win.count ? win.entries[win.selected].name : ""
        color: Theme.subtle
        font.family: Theme.monoFont
        font.pixelSize: Theme.wallpaperMetaSize
        font.weight: Font.DemiBold
      }

      Text {
        x: Theme.wallpaperWidth - Theme.wallpaperInset - width
        y: Theme.wallpaperFooterTop
        text: win.count > 0 ? (win.selected + 1) + " / " + win.count + "   ·   Enter to apply" : "No wallpapers in this folder"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: Theme.wallpaperMetaSize
      }
    }
  }
}
