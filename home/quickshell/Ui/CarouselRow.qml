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

  // The tile, as a Component whose root is a carousel Tile. The row leaves placement, selection
  // state and activation to the picker, since what Enter does differs per picker.
  property Component tile

  readonly property int count: model.length

  // Whether the rail and tiles glide to a new selection. They all read one spring, on the
  // selection index, so a tile's size and the rail's slide are the same motion and reach rest on
  // the same frame, with the selection holding the centre line all the way over. Tiles bind
  // their own `glide` to this (for their ring weight).
  property bool snapping: false
  readonly property bool glide: !Theme.reduceMotion && !root.snapping

  // Where the row is looking: the selection, followed at the island's pace. A whole number at
  // rest, between two while it moves.
  readonly property real position: positionSpring.value

  MorphSpring {
    id: positionSpring

    target: root.selected
    animate: !root.snapping
    epsilon: 0.001
    label: "carousel." + root.toString().replace(/^.*\(0x([0-9a-f]+)\).*$/, "$1")
  }

  // The room the row has: the panel's own width, not the token, so a narrow screen's clamp is
  // what the row centres on.
  readonly property real inner: root.width - 2 * Theme.wallpaperInset

  // The selected tile takes the first width, everything else the last, indexed by distance
  // from the selection and clamped to its end; see the token note. The distance is fractional
  // while the row moves, which blends the two widths either side of it.
  function tileWidth(i) {
    var widths = Theme.wallpaperTileWidths;
    var d = Math.min(Math.abs(i - root.position), widths.length - 1);
    var lo = Math.floor(d);
    var hi = Math.min(lo + 1, widths.length - 1);
    return widths[lo] + (widths[hi] - widths[lo]) * (d - lo);
  }

  function tileHeight(i) {
    return Math.round(root.tileWidth(i) / Theme.wallpaperTileAspect);
  }

  // Tiles share the row's middle line, so a taller one grows both ways.
  function tileY(i) {
    return Theme.wallpaperRowMid - root.tileHeight(i) / 2;
  }

  // Every tile's left edge (the last entry is the strip's end plus a gap): the sum of what is
  // before it, so selecting right pushes the row left. One pass per frame, not one per tile.
  readonly property var offsets: {
    var o = [0];
    for (var j = 0; j < root.count; j++)
      o.push(o[j] + root.tileWidth(j) + Theme.wallpaperTileGap);
    return o;
  }

  function tileX(i) {
    return root.offsets[i];
  }

  readonly property real stripWidth: count > 0 ? root.offsets[count] - Theme.wallpaperTileGap : 0

  // The centre of the tile the row is looking at, blended between two while it moves.
  readonly property real focusCentre: {
    if (count === 0)
      return 0;
    var p = Math.max(0, Math.min(count - 1, root.position));
    var i = Math.floor(p);
    var k = Math.min(i + 1, count - 1);
    var ci = root.offsets[i] + root.tileWidth(i) / 2;
    var ck = root.offsets[k] + root.tileWidth(k) / 2;
    return ci + (ck - ci) * (p - i);
  }

  // A fitting row is centred; otherwise the selection is pulled to the centre line, then
  // clamped so neither end passes the inset.
  readonly property real stripX: {
    if (stripWidth <= inner)
      return Theme.wallpaperInset + (inner - stripWidth) / 2;

    var wanted = root.width / 2 - root.focusCentre;
    var furthest = root.width - Theme.wallpaperInset - stripWidth;
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

      Repeater {
        model: root.model

        delegate: root.tile
      }
    }
  }
}
