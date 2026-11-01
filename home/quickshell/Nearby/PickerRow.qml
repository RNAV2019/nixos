import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One picker row: a glyph, a name, and the size or folder count. Marked rows wear the accent,
// the focused or current one a wash, and the focused one a bar at the edge.
ListRow {
  id: root

  property var entry: null
  property bool current: false
  property bool focusedRow: false
  property bool markedRow: false
  property bool showMeta: true
  property bool quiet: false

  readonly property string fileKind: entry ? (entry.dir ? "dir" : Nearby.fileKind(entry.name)) : "file"

  kind: ListRow.Flat
  // The picker keeps the keyboard itself; a click must not take its focus.
  activeFocusOnTab: false
  height: Theme.pickerRowHeight
  accessibleName: entry ? entry.name : ""
  flatColor: markedRow ? Theme.withAlpha(Theme.accentFill, focusedRow ? 0.16 : 0.09) : focusedRow || current ? Theme.withAlpha(Theme.inkPrimary, 0.06) : "transparent"
  glyph: Nearby.glyphFor(fileKind)
  glyphColor: Nearby.inkFor(fileKind)
  glyphSize: Theme.pickerGlyph
  glyphLeft: Theme.pickerGlyphLeft
  label: entry ? entry.name : ""
  labelColor: markedRow ? Theme.accentFill : quiet && !current ? Theme.inkSecondary : Theme.inkPrimary
  labelWeight: focusedRow || current ? Theme.weightSemi : Theme.weightRegular
  textLeft: Theme.pickerTextLeft
  textGap: 10
  value: !showMeta || !entry ? "" : entry.dir ? String(entry.size) : Nearby.sizeLabel(entry.size)
  valueColor: Theme.inkTertiary
  valueSize: Theme.pickerMetaSize
  valueInset: Theme.pickerMetaRight
  trailInset: Theme.pickerMetaRight

  trailing: StrokeIcon {
    visible: root.markedRow
    size: Theme.pickerMarkSize
    strokeWidth: 1.9
    path: IconPaths.check
    color: Theme.accentFill
  }

  Rectangle {
    visible: root.focusedRow
    x: 0
    y: (parent.height - height) / 2
    width: Theme.pickerFocusMarkWidth
    height: Theme.pickerFocusMarkHeight
    radius: width / 2
    color: Theme.accentFill
  }
}
