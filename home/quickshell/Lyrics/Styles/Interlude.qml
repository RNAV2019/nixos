import QtQuick
import qs.Commons
import qs.Services
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Between the words: the intro, a solo, the fade, and a song with no timed lyrics at all. The
// song's name, set large, and who it is by, drifting a little so nothing sits still on the
// panel; under them, where there is something to say, why there are no words.
LyricStyle {
  id: sty

  bloom: 0.5
  bloomKick: 0.1
  aberration: 0.0016
  grain: 0.06
  vignette: 0.5
  ground: 1.25

  // It has no words to time itself by, so it comes up on the wall's clock.
  property real startedAt: -1
  readonly property real age: startedAt < 0 ? 0 : stage.wall - startedAt

  Component.onCompleted: startedAt = stage.wall

  readonly property real swayX: Math.sin(stage.wall * 0.11) * 3 * u
  readonly property real swayY: Math.cos(stage.wall * 0.083) * 2 * u

  Column {
    id: block

    x: (sty.width - width) / 2 + sty.swayX
    y: (sty.height - height) / 2 + sty.swayY
    spacing: 2.4 * sty.u

    LyricText {
      id: title

      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(implicitWidth, sty.width * 0.8)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight
      lineHeight: 0.92
      text: Media.title
      size: (Media.title.length > 28 ? 7.5 : 11) * sty.u
      caps: false
      color: sty.ink
      opacity: Kinetic.outCubic(sty.age / 0.9)
      scale: 1 + 0.02 * sty.stage.level + 0.04 * (1 - Kinetic.outQuint(sty.age / 1.4))
    }

    LyricText {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(implicitWidth, sty.width * 0.7)
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: Media.artist
      font.family: Theme.lyricSerifFont
      font.weight: Font.Normal
      font.italic: true
      size: 5.4 * sty.u
      color: sty.accent
      opacity: Kinetic.outCubic((sty.age - 0.25) / 0.9)
    }

    Item {
      width: 1
      height: 1.6 * sty.u
      visible: status.visible
    }

    LyricText {
      id: status

      anchors.horizontalCenter: parent.horizontalCenter
      visible: text !== ""
      text: sty.stage.status
      font.family: Theme.uiFont
      font.weight: Theme.weightMedium
      // With no song to name, this line is all there is.
      size: (Media.title === "" ? 4.2 : 2.6) * sty.u
      color: Theme.withAlpha(sty.ink, 0.55)
      opacity: Kinetic.outCubic((sty.age - 0.6) / 0.9)
    }
  }
}
