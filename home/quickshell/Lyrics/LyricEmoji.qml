import QtQuick
import qs.Commons

// A word's picture on the lyric stage (word.emoji, from Emoji.js). The emoji face is a sheet of
// bitmaps about 136 px tall, so `size` is best kept near that and the rest left to `scale`.
Text {
  id: root

  property string glyph: ""
  property real size: 10

  text: glyph
  textFormat: Text.PlainText
  font.family: Theme.emojiFont
  font.pixelSize: Math.max(1, Math.round(size))
}
