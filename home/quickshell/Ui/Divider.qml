import QtQuick
import qs.Commons

// The hairline between a panel's sections. The caller sets its length: the width of a
// horizontal one, the height of a vertical one.
Rectangle {
  property bool vertical: false

  width: vertical ? 1 : implicitWidth
  height: vertical ? implicitHeight : 1
  color: Theme.withAlpha(Theme.highlightMed, Theme.dividerAlpha)
}
