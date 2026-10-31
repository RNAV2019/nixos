import QtQuick
import qs.Commons
import qs.Ui

// The island's Wi-Fi mark at a control's glyph size, inked in `color`, dimmed when offline.
WifiGlyph {
  property color color

  scale: Theme.controlTileGlyphSize / implicitWidth
  litColor: color
  dimColor: Theme.withAlpha(color, Theme.controlGlyphDimAlpha)
}
