import QtQuick
import qs.Commons

// A word on the lyric stage. Drawn from the glyphs' outlines (the curve renderer), so it stays
// sharp at any size and under any scale a style puts on it; a style sets `size` once and moves
// the word with `scale`, never by changing the size every frame, which would lay it out again.
Text {
  id: root

  // The pixel size.
  property real size: 10
  // Space added between letters, in ems (negative draws them together).
  property real tracking: 0

  renderType: Text.CurveRendering
  textFormat: Text.PlainText
  color: Theme.lyricInk
  font.family: Theme.lyricFont
  font.weight: Font.Black
  font.pixelSize: Math.max(1, Math.round(size))
  font.letterSpacing: tracking * Math.max(1, Math.round(size))
}
