import QtQuick
import qs.Commons

// A quiet heading. Sentence case rather than shouted caps: weight and colour
// carry the hierarchy, and hardware names such as eDP-1 keep their own casing.
Text {
  property string title: ""
  // Connector names and other identifiers sit better on the monospace face.
  property bool mono: false

  text: title
  color: Theme.subtle
  font.family: mono ? Theme.monoFont : Theme.uiFont
  font.pixelSize: Theme.fontSize
  font.weight: Theme.weightSemi
  font.letterSpacing: mono ? 0 : Theme.trackingLabel
  elide: Text.ElideRight
}
