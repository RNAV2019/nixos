import QtQuick
import qs.Commons

// The hairline between a panel's sections. The caller sets its length: the width of a
// horizontal one, the height of a vertical one. `alpha` is for a rule that sits quieter than
// the rest, like the file picker's column rules.
Rectangle {
  property bool vertical: false
  property real alpha: Theme.dividerAlpha

  width: vertical ? 1 : implicitWidth
  height: vertical ? implicitHeight : 1
  color: Theme.withAlpha(Theme.highlightMed, alpha)
}
