import QtQuick
import qs.Commons

// The media card's transport glyphs, from the shell's one icon set.
Item {
  id: root

  // "play", "pause", "next" or "previous".
  property string kind: "play"
  property color color: "white"

  // Large enough that play's triangle keeps the ink the hand-drawn one had (about 13 x 15).
  readonly property real glyphSize: 30

  implicitWidth: glyphSize
  implicitHeight: glyphSize

  Text {
    anchors.centerIn: parent
    text: root.kind === "pause" ? Icons.pause : root.kind === "next" ? Icons.next : root.kind === "previous" ? Icons.previous : Icons.play
    color: root.color
    font.family: Theme.iconFont
    font.pixelSize: root.glyphSize
  }
}
