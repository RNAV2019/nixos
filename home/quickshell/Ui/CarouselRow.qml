import QtQuick
import qs.Commons

// The carousel row shared by the theme and wallpaper pickers: one strip of tiles arranged as
// a ring, the selection pulled to the centre line and clamped so neither end passes the
// inset. The strip is clipped to the panel, not the inset, so a long row is cut by the
// panel's own edge and reads as running on past it. With few enough tiles to fit the row is
// simply centred, which is all the theme picker's two ever do.
Item {
  id: root

  // Entries of any shape; the tile Component reads what it needs from them.
  property var model: []
  property int selected: 0

  // The tile, as a Component whose root is a TileBase. The row leaves placement, selection
  // state and activation to the picker, since what Enter does differs per picker.
  property Component tile

  readonly property int count: model.length

  // Whether the rail and tiles glide to a new selection. Every piece rides the same spring
  // from the same instant, so a tile's size and the rail's slide stay in step and the
  // selection holds the centre line all the way over. Tiles bind their own `glide` to this.
  property bool snapping: false
  readonly property bool glide: !Theme.reduceMotion && !root.snapping

  // The room the row has.
  readonly property real inner: Theme.wallpaperWidth - 2 * Theme.wallpaperInset

  // The selected tile takes the first width, everything else the last, indexed by distance
  // from the selection and clamped to its end; see the token note.
  function tileWidth(i) {
    var widths = Theme.wallpaperTileWidths;
    var d = Math.abs(i - root.selected);
    return widths[Math.min(d, widths.length - 1)];
  }

  function tileHeight(i) {
    return Math.round(root.tileWidth(i) / Theme.wallpaperTileAspect);
  }

  // A tile's left edge is the sum before it, so selecting right pushes the row left.
  function tileX(i) {
    var x = 0;
    for (var j = 0; j < i; j++)
      x += root.tileWidth(j) + Theme.wallpaperTileGap;
    return x;
  }

  readonly property real stripWidth: count > 0 ? root.tileX(count) - Theme.wallpaperTileGap : 0

  // A fitting row is centred; otherwise the selection is pulled to the centre line, then
  // clamped so neither end passes the inset.
  readonly property real stripX: {
    if (stripWidth <= inner)
      return Theme.wallpaperInset + (inner - stripWidth) / 2;

    var wanted = Theme.wallpaperWidth / 2 - (root.tileX(root.selected) + root.tileWidth(root.selected) / 2);
    var furthest = Theme.wallpaperWidth - Theme.wallpaperInset - stripWidth;
    return Math.max(furthest, Math.min(Theme.wallpaperInset, wanted));
  }

  // The row is a ring: stepping past either end comes out at the other. The modulo survives
  // a negative delta, since JavaScript's % keeps the left sign.
  function step(delta) {
    if (count === 0)
      return;
    root.selected = ((root.selected + delta) % count + count) % count;
  }

  // Selects without the glide, for seeding the row as the panel opens: the panel is already
  // morphing, and a row sliding under it would be a second motion with nothing to say.
  function jump(i) {
    root.snapping = true;
    root.selected = i;
    root.snapping = false;
  }

  Item {
    id: strip

    anchors.fill: parent
    clip: true

    Item {
      id: rail

      x: root.stripX
      y: 0
      width: root.stripWidth
      height: parent.height

      Behavior on x {
        enabled: root.glide

        SurfaceSpring {}
      }

      Repeater {
        model: root.model

        delegate: root.tile
      }
    }
  }
}
