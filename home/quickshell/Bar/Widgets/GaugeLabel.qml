import QtQuick
import qs.Commons

// The reading in the gap at the foot of an island gauge. Anchors are left to the caller:
// gauge layouts differ about whether the label shares the gap.
Text {
  color: Theme.subtle
  font.family: Theme.uiFont
  font.pixelSize: 11
  font.weight: Font.DemiBold
}
