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
  // White in steps, like every inner fill; `alpha` scales it from the standard rule.
  color: Theme.lift(Theme.liftDivider * alpha / Theme.dividerAlpha)
}
