import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One arrival under "Received" (boards 16g, 16h): the file's glyph, its name and its size, with
// the download's progress drawn as the row's own background. A row that has just landed wears
// the accent ground and edge for a few seconds; a finished row opens its file on click.
ListRow {
  id: root

  // The transfer row from the daemon (direction "in", state "in_progress" or "finished").
  required property var transfer
  // True while the row wears its arrival accent.
  property bool fresh: false
  // 0..1, drawn as the row's background fill.
  property real progress: 1

  // The cursor over the row, in the row's own coordinates, so the panel can float a preview.
  signal hoverMoved(real localX, real localY)
  signal hoverExited

  readonly property bool done: transfer && transfer.state === "finished"
  readonly property string name: Nearby.transferName(transfer)
  readonly property string path: {
    var paths = transfer && transfer.saved_paths ? transfer.saved_paths : [];
    return paths.length > 0 ? String(paths[0]) : "";
  }
  readonly property string fileKind: Nearby.fileKind(name)
  readonly property bool isImage: Nearby.isPreviewableImage(name)

  readonly property string sizeLabel: {
    if (!transfer || !transfer.total_bytes)
      return "";
    if (!done)
      return Math.round(Theme.clamp01(progress) * 100) + "%";
    return Nearby.sizeLabel(transfer.total_bytes);
  }

  kind: ListRow.Hairline
  interactive: done
  accented: fresh
  fillProgress: done ? -1 : progress
  // The edge sits over the masked ground, as the board draws it.
  edgeOver: true
  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyRowHeight
  glyph: Nearby.glyphFor(fileKind)
  glyphColor: Theme.accentFill
  glyphSize: Theme.nearbyRowGlyph
  label: name
  elide: Text.ElideMiddle
  textLeft: Theme.nearbyRowTextLeft
  value: sizeLabel
  valueColor: done ? Theme.inkSecondary : Theme.accentFill
  valueSize: Theme.nearbyRowMetaSize
  valueInset: Theme.nearbyRowInset

  HoverHandler {
    onPointChanged: root.hoverMoved(point.position.x, point.position.y)
    onHoveredChanged: {
      if (hovered)
        root.hoverMoved(point.position.x, point.position.y);
      else
        root.hoverExited();
    }
  }
}
