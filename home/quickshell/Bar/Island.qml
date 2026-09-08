import QtQuick
import Quickshell
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The centred surface, and the only one that changes shape.
//
// It has three resting states. Idle it is a clock and nothing else. With a
// player running it grows an equaliser beside the clock. Hovered, or pinned by
// a click, it opens into a card carrying the track, the clock with its date,
// and the two readings worth watching all day.
//
// The open is not a cross-fade. Measured frame by frame against the source
// recording, the card's contents scale up with the pill, and the track block
// is cut off by the room it currently has, so the title is revealed letter by
// letter as the pill widens. The clock is the one element both states share:
// it interpolates its own size and slides into place rather than being swapped
// for a second copy.
FrostedSurface {
  id: root

  signal clockActivated
  signal statusActivated

  // A pin holds the card open once the pointer leaves. Clicking again drops it
  // back to plain hover behaviour.
  property bool pinned: false

  readonly property bool expanded: pinned || hover.containsMouse

  clipContent: true

  readonly property int collapsedWidth: Media.active ? Theme.islandPlayingWidth : Theme.islandIdleWidth

  implicitWidth: expanded ? Theme.islandExpandedWidth : collapsedWidth
  implicitHeight: expanded ? Theme.islandExpandedHeight : Theme.barHeight
  surfaceRadius: expanded ? Theme.islandExpandedRadius : Theme.islandRadius

  Behavior on implicitWidth {
    Morph {}
  }

  Behavior on implicitHeight {
    Morph {}
  }

  Behavior on surfaceRadius {
    Morph {}
  }

  // Everything the card draws is sized against the pill's own height, so one
  // animated property carries the whole layout and nothing can fall out of
  // step with the shape.
  readonly property real scaleFactor: height / Theme.islandExpandedHeight

  // The same progress expressed as 0 while shut and 1 while open, for the
  // handful of things that travel between two fixed states rather than scale.
  readonly property real openness: {
    var span = Theme.islandExpandedHeight - Theme.barHeight;
    return span <= 0 ? 1 : Math.max(0, Math.min(1, (height - Theme.barHeight) / span));
  }

  readonly property real midline: height / 2

  // The clock is drawn at its open size and scaled, so its left edge is not
  // where its unscaled box begins. Everything that has to stop short of the
  // clock measures against this instead.
  readonly property real clockLeft: clockLabel.x + clockLabel.width * (1 - clockLabel.scale) / 2

  // The date is wider than the clock, so while the card is small it is the
  // date, not the clock, that the track block has to stop short of.
  readonly property real centreLeft: Math.min(clockLeft, date.x + date.width * (1 - date.scale) / 2)

  // True only once the morph has come to rest.
  readonly property bool settled: openness >= 1

  // Shut, the clock shares the pill with the equaliser and the pair is centred
  // together, so the clock itself sits right of centre by half the equaliser.
  readonly property real clockShift: Media.active ? (collapsedEq.implicitWidth + collapsedGap) / 2 : 0

  readonly property real collapsedGap: 7.5

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  // Clicking empty island space pins the card open; clicking again releases it
  // to plain hover behaviour. The controls sit on top of this and act without
  // disturbing the pin.
  MouseArea {
    id: hover

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.pinned = !root.pinned
  }

  // The equaliser the shut pill carries. The open card has its own beside the
  // title, so this one only has to hand over.
  Equaliser {
    id: collapsedEq

    x: root.clockLeft - root.collapsedGap - implicitWidth
    y: root.midline - implicitHeight / 2
    playing: Media.playing
    visible: Media.active && opacity > 0
    opacity: root.expanded ? 0 : 1

    Behavior on opacity {
      Morph {
        duration: Theme.morphContent
      }
    }
  }

  // The card. Laid out against the pill's live width rather than a fixed
  // design width, which is what makes the contents reflow as it opens.
  Item {
    id: card

    anchors.fill: parent
    opacity: root.expanded ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.morphContent
      }
    }

    // The track block is drawn once at its open metrics and scaled as a whole,
    // and the room it has is a clip rather than an elide. Animating each font
    // size and each text width instead re-fits the glyphs on every frame, and
    // the trailing letters flicker as they trade places with the ellipsis. The
    // source shell does not do that: no frame of the open shows an ellipsis,
    // only a title cut off mid-word.
    Item {
      id: media

      x: 16 * root.scaleFactor
      y: root.midline - height * root.scaleFactor / 2
      width: root.scaleFactor > 0 ? Math.max(0, (root.centreLeft - 28 * root.scaleFactor) / root.scaleFactor) : 0
      height: Theme.islandExpandedHeight
      transformOrigin: Item.TopLeft
      scale: root.scaleFactor
      clip: true
      visible: Media.active

      AlbumArt {
        id: cover

        x: 0
        y: (parent.height - height) / 2
        width: Theme.islandArtSize
        height: width
      }

      Equaliser {
        id: cardEq

        x: 60
        y: (parent.height - height) / 2
        playing: Media.playing
      }

      Text {
        id: title

        x: 84
        y: parent.height / 2 - 8 - height / 2
        width: Math.max(0, parent.width - x)
        // Only once the morph stops, so the ellipsis never appears mid-motion.
        elide: root.settled ? Text.ElideRight : Text.ElideNone
        text: Media.title
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandTitleSize
        font.weight: Font.DemiBold
      }

      Text {
        x: title.x
        y: parent.height / 2 + 9.5 - height / 2
        width: title.width
        elide: root.settled ? Text.ElideRight : Text.ElideNone
        text: Media.artist
        color: Theme.subtle
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandCaptionSize
      }
    }

    // Left and right buttons skip, so the card is a transport as well as a
    // readout. Kept outside the scaled block so it stays in real coordinates.
    MouseArea {
      x: 0
      y: 0
      width: Math.max(0, root.centreLeft - 12 * root.scaleFactor)
      height: parent.height
      enabled: Media.active && root.expanded
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.ForwardButton | Qt.BackButton
      onClicked: function (event) {
        if (event.button === Qt.ForwardButton)
          Media.next();
        else if (event.button === Qt.BackButton)
          Media.previous();
        else
          Media.toggle();
      }
    }

    Text {
      id: date

      x: (root.width - width) / 2
      y: root.midline + 13.5 * root.scaleFactor - height / 2
      transformOrigin: Item.Center
      scale: root.scaleFactor
      text: Qt.formatDateTime(clock.date, "ddd, d MMM")
      color: Theme.subtle
      font.family: Theme.uiFont
      font.pixelSize: Theme.islandCaptionSize
    }

    Rectangle {
      id: status

      // Anchored to the right edge with a margin that scales like every other
      // measurement on the card.
      x: root.width - 88 * root.scaleFactor
      y: root.midline - height / 2
      width: Theme.islandStatusWidth * root.scaleFactor
      height: 36 * root.scaleFactor
      radius: height / 2
      color: Theme.withAlpha(Theme.accent, 0.14)
      border.width: 1
      border.color: Theme.withAlpha(Theme.accent, 0.28)

      WifiGlyph {
        x: 10 * root.scaleFactor
        y: (parent.height - implicitHeight * root.scaleFactor) / 2
        transformOrigin: Item.TopLeft
        scale: root.scaleFactor
      }

      BatteryGauge {
        x: 33 * root.scaleFactor
        y: (parent.height - implicitHeight * root.scaleFactor) / 2
        transformOrigin: Item.TopLeft
        scale: root.scaleFactor
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.statusActivated()
      }
    }
  }

  // The clock belongs to neither state and survives both. It grows from the
  // shut size to the open one and slides off the equaliser onto the pill's
  // centre line, so it is never seen to be replaced.
  Text {
    id: clockLabel

    // Set at the open size and scaled down, rather than having its pixel size
    // animated. The digits are then laid out once and the advance between them
    // never shifts, so the colon and the minutes stay put as it grows.
    readonly property real shownSize: Theme.islandClockSize + root.openness * (Theme.islandDisplaySize - Theme.islandClockSize)

    x: (root.width - width) / 2 + (1 - root.openness) * root.clockShift
    y: root.midline - 8 * root.openness - height / 2
    transformOrigin: Item.Center
    scale: shownSize / Theme.islandDisplaySize
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.islandDisplaySize
    font.weight: Font.DemiBold
  }

  // Sits over the clock and its date, and only takes clicks once the card that
  // the panel belongs to is actually open.
  MouseArea {
    x: root.clockLeft - 12 * root.scaleFactor
    y: 0
    width: clockLabel.width * clockLabel.scale + 24 * root.scaleFactor
    height: root.height
    enabled: root.expanded
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clockActivated()
  }
}
