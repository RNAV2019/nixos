import QtQuick
import qs.Commons
import qs.Ui

// One row under the capture tiles: a quiet pill with the label at the near end and, at the
// far end, whatever control the row carries (a switch, the frame-rate segments), given as
// `trailing`. A click anywhere else on the row is the row's own, for the toggle or the cycle.
ListRow {
  id: root

  // A toggle that is off reads muted.
  property bool lit: true

  x: Theme.recorderInset
  width: parent.width - Theme.recorderInset * 2
  implicitHeight: Theme.recorderRowHeight

  kind: ListRow.Grouped
  // The picker keeps the keyboard (Enter starts the capture, C/A/M/F flip these), so a click
  // on the row must not take the focus, and Tab must not stop here.
  activeFocusOnTab: false
  textLeft: Theme.recorderRowTextLeft
  trailInset: Theme.recorderRowTextLeft
  labelSize: Theme.recorderRowLabelSize
  labelWeight: Theme.weightMedium
  labelColor: lit ? Theme.inkPrimary : Theme.inkTertiary
}
