import QtQuick
import qs.Commons

// The theme and wallpaper pickers are this one panel: a title with the palette's name over a
// single row of tiles, and a footer naming where the choice comes from. The picker supplies the
// entries, which of them is up, the tile to draw each as, and what applying one does.
Panel {
  id: root

  property var entries: []
  // The entry that is up, or -1 while that is not yet known.
  property int current: -1
  // A Component whose root is a carousel Tile, placed by the row (see CarouselRow.tileX).
  property Component tile

  property string footerPath: ""
  property string footerName: ""
  property string emptyHint: ""

  property alias carousel: row
  readonly property int selected: row.selected
  readonly property int count: row.count

  // Raised by Enter or a click on a tile, just before the panel closes.
  signal chosen(int index)

  // The panel opens on what is up. That is not always known as it opens (the wallpaper list is
  // read off disk), so the open is a pending seed that lands when `current` does, and the
  // first step by hand ends it, so a late answer never overwrites the keys.
  property bool seeding: false

  function reseed() {
    seeding = true;
    seed();
  }

  function seed() {
    if (!seeding || current < 0)
      return;
    row.jump(current);
    seeding = false;
  }

  onCurrentChanged: seed()
  onEntriesChanged: seed()

  // Nothing previews: changing the desktop under every arrow key would repaint it repeatedly
  // on the way to a choice.
  function activate() {
    if (row.selected < 0 || row.selected >= row.count)
      return;
    seeding = false;
    root.chosen(row.selected);
    root.surface.hide();
  }

  function choose(index) {
    row.selected = index;
    root.activate();
  }

  function step(delta) {
    seeding = false;
    row.step(delta);
  }

  headerTop: Theme.wallpaperHeaderTop
  meta: Theme.paletteName
  footerShown: true
  takesMove: true
  takesTab: true
  takesActivate: true

  footer.path: root.footerPath
  footer.name: root.footerName
  footer.count: root.count > 0 ? (root.selected + 1) + " / " + root.count + "   ·   " : ""
  footer.hint: root.count > 0 ? "Enter to apply" : root.emptyHint

  onMoved: function (dx, dy) {
    root.step(dx + dy);
  }
  onStepped: function (delta) {
    root.step(delta);
  }
  onActivated: root.activate()

  onKeyPressed: function (event) {
    switch (event.key) {
    case Qt.Key_Home:
      seeding = false;
      row.selected = 0;
      break;
    case Qt.Key_End:
      seeding = false;
      row.selected = Math.max(0, row.count - 1);
      break;
    default:
      return;
    }
    event.accepted = true;
  }

  // Which one the ring is on, not the one that is up: that is `current`.
  CarouselRow {
    id: row

    anchors.fill: parent
    model: root.entries
    tile: root.tile
  }
}
