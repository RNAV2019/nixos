import QtQuick
import qs.Commons

// A word on the lyric stage. Drawn from the glyphs' outlines (the curve renderer), so it stays
// sharp at any size and under any scale a style puts on it; a style sets `size` once and moves
// the word with `scale`, never by changing the size every frame, which would lay it out again.
Text {
  id: root

  // One of Theme.lyricFaces, or null for the stage's display face.
  property var face: null
  // The pixel size before the face's own factor.
  property real size: 10
  // Set false to keep a face that prefers capitals in mixed case.
  property bool caps: face ? face.caps : false

  renderType: Text.CurveRendering
  textFormat: Text.PlainText
  color: Theme.lyricInk
  font.family: face ? face.family : Theme.lyricDisplayFont
  font.weight: face ? face.weight : Font.Black
  font.italic: face ? face.italic : false
  font.pixelSize: Math.max(1, Math.round(size * (face ? face.size : 1)))
  font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
}
