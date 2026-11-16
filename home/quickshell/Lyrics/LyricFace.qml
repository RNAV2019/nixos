import QtQuick
import qs.Commons
import qs.Services
import "Pill.js" as Pill

// What the shut pill shows of a song in place of its clock, centred in the pill, which is grown to
// its width (Services/Lyrics.qml `pillWidth`): the line being sung, three dots while nobody sings,
// the song's title at its start. All of it is drawn from the song's time alone (Pill.js), so the
// bar's island and a surface closing into it (Ui/CollapsedPill.qml) draw the same picture and one
// can take over from the other on any frame.
//
// A word comes up from under its place a moment after the word before it, fills letter by letter
// behind a soft front as it is sung, stands a little proud of the line while it is, and eases back
// among the sung. A line leaves upward as the next comes up under it. Two lines are kept, the one
// up and the one leaving: phrases with an even number in one, odd in the other, so a line keeps
// its place for as long as it is on screen.
//
// Draw this under whatever takes the pointer, never over it: a Text set as styled text takes
// hover for itself (Bar/Island.qml).
Item {
  id: root

  // 0 the clock's pill, 1 this: its owner's fade between the two.
  property real presence: 0
  // Whether the pill's ends shade what has not room yet. For an owner that crops its contents to
  // the pill's own shape (the island): the shades are square, and uncropped their corners show.
  property bool shaded: true

  // Nothing is worked out per frame while none of this is on screen.
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

    // By the width the phrase was measured at, not the row's own: a row has none until the
    // frame after it is given its words.
    x: (root.width - (line.phrase ? line.phrase.width : 0)) / 2
    height: root.height
    visible: phrase !== null && gone < 1

    Row {
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
    phrase: root.held(0)
  }

  Line {
    phrase: root.held(1)
  }

  // One of the title's two parts, which come up and leave as a line's words do.
  component Part: Text {
    property int order: 0
    readonly property real came: Pill.arrived(title.span, order * 3, root.now)

    y: (title.height - height) / 2 + Theme.lyricRise * (1 - came) - Theme.lyricLeaveRise * title.gone * title.gone
    opacity: came * (1 - title.gone) * (1 - title.gone)
    font.family: Theme.uiFont
    font.pixelSize: Theme.islandLyricSize
  }

  // The song named at its start: the title, and the artist beside it where both fit, the artist
  // a moment after the title.
  Item {
    id: title

    readonly property var span: Lyrics.titled
    readonly property real gone: Pill.left(title.span, root.now)

    x: (root.width - Lyrics.titleWidth) / 2
    height: root.height
    visible: span !== null && gone < 1

    Part {
      width: Lyrics.titleShown
      elide: Text.ElideRight
      text: Lyrics.titleText
      color: Theme.text
      font.weight: Theme.weightSemi
    }

    Part {
      order: 1
      x: Lyrics.titleShown + Theme.islandLyricTitleGap
      visible: Lyrics.artistShown
      text: Lyrics.track.artist
      color: Theme.withAlpha(Theme.text, Theme.lyricArtistAlpha)
      font.weight: Theme.weightMedium
    }
  }

  // Nobody singing and a line to come: three dots, breathing while they wait and lit one by one
  // over the last seconds before the voice.
  Row {
    id: dots

    readonly property var wait: Lyrics.facing !== null && Lyrics.facing.kind === "dots" ? Lyrics.facing : null

    x: (root.width - width) / 2
    y: (root.height - height) / 2
    spacing: Theme.lyricDotGap
    opacity: wait ? Pill.dotsShown(wait, root.now) : 0
    visible: opacity > 0

    Repeater {
      model: 3

      Rectangle {
        required property int index

        readonly property real lit: dots.wait ? Pill.dotLit(dots.wait, index, root.now) : 0
        readonly property real breath: dots.wait ? Pill.dotBreath(dots.wait, index, root.now) : 0

        width: Theme.lyricDotSize
        height: Theme.lyricDotSize
        radius: width / 2
        color: Theme.text
        opacity: Theme.lyricDotUnlit + (1 - Theme.lyricDotUnlit) * lit + Theme.lyricDotBreathAlpha * breath
        scale: Theme.lyricDotSmall + (1 - Theme.lyricDotSmall) * lit + Theme.lyricDotBreathSize * breath
      }
    }
  }

  // The pill's ends shade what has not room yet, while the shape is still on its way to its
  // width; at rest everything ends short of both.
  component Shade: Rectangle {
    id: shade

    property bool leading: true

    visible: root.shaded
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
