import QtQuick
import qs.Commons
import qs.Services
import "Pill.js" as Pill

// The words of what is playing as the shut pill shows them: one line, centred, the pill grown
// to its width (Bar/Island.qml). Each word is drawn from the song's time alone (Pill.js): it
// comes up from under its place a moment after the word before it, fills letter by letter
// behind a soft front as it is sung, stands a little proud of the line while it is, and eases
// back among the sung. A line leaves upward as the next comes up under it.
//
// Two lines are kept, the one up and the one leaving: phrases with an even number in one, odd
// in the other, so a line keeps its place for as long as it is on screen.
Item {
  id: root

  // 0 the plain pill, 1 the words: the island's fade between the two.
  property real presence: 0

  // The width of the line the pill is wide for; 0 with none. As it was measured when the song's
  // lines were cut (Services/Lyrics.qml), not as it is laid out here: a row has no width until
  // the frame after it is given its words, and the pill would start back towards nothing for it.
  readonly property real textWidth: Lyrics.index >= 0 && Lyrics.index < Lyrics.phrases.length ? Lyrics.phrases[Lyrics.index].width : 0

  // Nothing is worked out per frame while the words are not on screen.
  readonly property real now: visible ? Lyrics.now : 0
  readonly property string ink: Pill.hex2(Theme.text.r) + Pill.hex2(Theme.text.g) + Pill.hex2(Theme.text.b)

  opacity: presence
  visible: opacity > 0

  // The phrase a line holds: the latest to come up or the one before it, whichever is its kind.
  function held(kind) {
    var i = Lyrics.latest;
    if (i < 0)
      return null;
    if (i % 2 !== kind)
      i -= 1;
    return i >= 0 && i < Lyrics.phrases.length ? Lyrics.phrases[i] : null;
  }

  component Line: Item {
    id: line

    property var phrase: null
    readonly property real gone: Pill.left(line.phrase, root.now)

    x: (root.width - width) / 2
    width: words.implicitWidth
    height: root.height
    visible: phrase !== null && gone < 1

    Row {
      id: words

      height: parent.height
      spacing: Lyrics.wordGap

      Repeater {
        model: line.phrase ? line.phrase.words : []

        Text {
          id: word

          required property var modelData
          required property int index

          readonly property real sung: Pill.fill(modelData, root.now)
          readonly property real proud: Pill.swell(modelData, root.now)
          readonly property real came: Pill.arrived(line.phrase, index, root.now)
          readonly property real back: sung >= 1 ? Pill.settled(modelData, root.now) : 0

          y: (line.height - height) / 2 + Theme.lyricRise * (1 - came) - Theme.lyricLeaveRise * line.gone * line.gone - Theme.lyricLift * proud
          opacity: came * (1 - line.gone) * (1 - line.gone)
          // A held word grows, but never so far that it closes on its neighbours.
          scale: 1 + Math.min(Theme.lyricHeldGrow, Theme.lyricHeldGrowMost / Math.max(1, width)) * Pill.weight(modelData) * proud
          transformOrigin: Item.Center

          textFormat: Text.StyledText
          text: sung > 0 && sung < 1 ? Pill.swept(modelData.text, sung, root.ink, Theme.lyricUnsungAlpha, 1) : Pill.escaped(modelData.text)
          color: Theme.withAlpha(Theme.text, sung >= 1 ? 1 - (1 - Theme.lyricSungAlpha) * back : Theme.lyricUnsungAlpha)
          font.family: Theme.uiFont
          font.pixelSize: Theme.islandLyricSize
          font.weight: Theme.weightSemi
        }
      }
    }
  }

  Line {
    id: even

    phrase: root.held(0)
  }

  Line {
    id: odd

    phrase: root.held(1)
  }

  // The pill's ends shade a word that has not room yet, while the shape is still on its way to
  // the line's width; at rest the words end short of both.
  component Shade: Rectangle {
    id: shade

    property bool leading: true

    x: leading ? 0 : root.width - width
    width: Theme.islandLyricShade
    height: root.height

    gradient: Gradient {
      orientation: Gradient.Horizontal

      GradientStop {
        position: 0
        color: Theme.withAlpha(Theme.surface, shade.leading ? 1 : 0)
      }

      GradientStop {
        position: 1
        color: Theme.withAlpha(Theme.surface, shade.leading ? 0 : 1)
      }
    }
  }

  Shade {}

  Shade {
    leading: false
  }
}
