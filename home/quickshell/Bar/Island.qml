import QtQuick
import Quickshell
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The centred surface, and the only one that changes shape. Idle it is a clock and nothing
// else; with a player running it grows an equaliser beside the clock; hovered, or pinned by
// a click, it opens into a card carrying the track, the clock with its date, and the two
// readings worth watching all day.
//
// The open is not a cross-fade. The card's contents scale up with the pill and the track
// block is cut off by the room it has, so the title is revealed letter by letter as the
// pill widens. The clock is the one element both states share, and it interpolates its own
// size rather than being swapped for a second copy.
FrostedSurface {
  id: root

  signal clockActivated
  signal statusActivated

  // A pin holds the card open once the pointer leaves. Clicking again drops it.
  property bool pinned: false

  // The output this island is on. The card is an item on the bar rather than a window of
  // its own, so a surface growing out of it matches against this; see Ui/IslandOrigin.qml.
  property string screenName: ""

  // Raised while another surface has taken the island's place. The island stays mapped for
  // handoff timing, but is not painted while the covering surface samples the desktop.
  property bool suppressed: false

  // Whether the surface covering it is one that stays. For the launcher and the control
  // centre a pin is dropped, so the card is not found still open underneath when they close.
  // The OSD is not: a volume key has no business closing a card the user pinned open.
  property bool replaced: false

  // Keep the pill out of Hyprland's backdrop-blur sample while another surface grows over it.
  opacity: suppressed ? 0 : 1

  onSuppressedChanged: {
    if (suppressed) {
      openDelay.stop();
      closeGrace.stop();
      hoverOpen = false;
      if (replaced)
        pinned = false;
    }
  }

  property bool hoverOpen: false
  readonly property bool expanded: !suppressed && (pinned || hoverOpen)

  // Both delays are the source's, timed off six hover opens and six closes: about 50 ms from
  // the pointer landing on the pill to the card starting to grow, and about 40 ms from it
  // leaving to the shrink. Both are upper bounds, including input and capture latency.
  Timer {
    id: openDelay

    interval: 50
    onTriggered: if (hover.containsMouse)
      root.hoverOpen = true
  }

  Timer {
    id: closeGrace

    interval: 40
    onTriggered: if (!hover.containsMouse && !root.pinned)
      root.hoverOpen = false
  }

  onPinnedChanged: {
    if (pinned) {
      closeGrace.stop();
      hoverOpen = true;
    } else if (!hover.containsMouse) {
      closeGrace.restart();
    }
  }

  // Offer the card to whatever might have to grow out of it. Only one island can be under
  // the pointer, so only one is ever the one on offer.
  onExpandedChanged: {
    if (expanded)
      Bus.islandCard = root;
    else if (Bus.islandCard === root)
      Bus.islandCard = null;
  }

  clipContent: true

  readonly property int collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

  implicitWidth: expanded ? Theme.islandExpandedWidth : collapsedWidth
  implicitHeight: expanded ? Theme.islandExpandedHeight : Theme.barHeight

  // The corner is read off the height rather than animated. A per-frame fit against the
  // recordings gives radius = min(height / 2, the surface's own radius) to 1.25 px rms,
  // against 5.32 px for an interpolated radius, and it keeps the shape a true stadium until
  // it is tall enough for the corner to bite.
  surfaceRadius: Math.min(height / 2, Theme.islandExpandedRadius)

  Behavior on implicitWidth {
    Morph {}
  }

  Behavior on implicitHeight {
    Morph {}
  }

  // Everything the card draws is sized against the pill's own height, so one animated
  // property carries the whole layout and nothing can fall out of step with the shape.
  readonly property real scaleFactor: height / Theme.islandExpandedHeight

  // The same progress as 0 while shut and 1 while open, for the things that travel between
  // two fixed states rather than scale.
  readonly property real openness: {
    var span = Theme.islandExpandedHeight - Theme.barHeight;
    return span <= 0 ? 1 : Math.max(0, Math.min(1, (height - Theme.barHeight) / span));
  }

  readonly property real midline: height / 2

  // The clock is drawn at its open size and scaled, so its left edge is not where its
  // unscaled box begins. Everything that stops short of the clock measures against this.
  readonly property real clockLeft: clockLabel.x + clockLabel.width * (1 - clockLabel.scale) / 2

  // The date is wider than the clock, so while the card is small it is the date the track
  // block has to stop short of.
  readonly property real centreLeft: Math.min(clockLeft, date.x + date.width * (1 - date.scale) / 2)

  // True only once the morph has come to rest.
  readonly property bool settled: openness >= 1

  // The shut pill is one row on 34 px margins, and every board width is that row plus 68.
  // The equaliser's shoulder and the dot's differ, so the clock shifts with the row and only
  // the idle pill finds it back on the centre line. See Theme.islandCollapsedWidth.
  readonly property real collapsedGap: 7.5

  // Where the shut row puts the clock's left edge. The label is drawn at its open size and
  // scaled, so this is the shown left edge, measured the way clockLeft measures it.
  readonly property real collapsedClockLeft: {
    var shoulder = Media.active ? collapsedEq.implicitWidth + collapsedGap : 0;
    var row = shoulder + clockLabel.width * clockLabel.scale;
    if (Recorder.recording)
      row += Theme.recorderDotGap + Theme.recorderDotSize;
    return (root.width - row) / 2 + shoulder;
  }

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  // Clicking empty island space pins the card open; clicking again releases it. The controls
  // sit on top of this and act without disturbing the pin.
  MouseArea {
    id: hover

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: {
      if (containsMouse) {
        closeGrace.stop();
        if (!root.pinned)
          openDelay.restart();
      } else {
        openDelay.stop();
        if (!root.pinned)
          closeGrace.restart();
      }
    }
    onClicked: root.pinned = !root.pinned
  }

  Rectangle {
    x: root.width / 2 - 1
    y: 5
    width: 2
    height: 6
    radius: 1
    color: Theme.accent
    visible: root.pinned && root.expanded
    opacity: 0.9
  }

  // The recording mark, the trailing element on the pill after the clock, so the equaliser
  // keeps the place beside the clock it already had. Love rather than accent, and shown only
  // while the pill is shut: a red dot in the open card would be a second subject.
  Rectangle {
    x: root.clockLeft + clockLabel.width * clockLabel.scale + Theme.recorderDotGap
    y: root.midline - height / 2
    width: Theme.recorderDotSize
    height: width
    radius: width / 2
    color: Theme.urgent
    visible: Recorder.recording && opacity > 0
    opacity: root.expanded ? 0 : 1

    Behavior on opacity {
      Morph {
        duration: Theme.morphContent
      }
    }
  }

  // The equaliser the shut pill carries. The open card has its own, so this one hands over.
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

  // The card, laid out against the pill's live width rather than a fixed design width, which
  // is what makes the contents reflow as it opens.
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

    // The track block is drawn once at its open metrics and scaled as a whole, and the room
    // it has is a clip rather than an elide. Animating each font size instead re-fits the
    // glyphs every frame, and the trailing letters flicker against the ellipsis.
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

    // With nothing playing, the room the track block would have taken carries the week
    // instead, drawn from the card's own left inset and scaled as a whole like the block it
    // replaces, so the strip grows with the pill rather than reflowing inside it.
    MiniCalendar {
      x: 16 * root.scaleFactor
      y: root.midline - height * root.scaleFactor / 2
      transformOrigin: Item.TopLeft
      scale: root.scaleFactor
      today: clock.date
      visible: !Media.active
    }

    // Left and right buttons skip, so the card is a transport as well as a readout. Kept
    // outside the scaled block so it stays in real coordinates.
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

      // Anchored right with a margin that scales like every other measurement on the card.
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

  // The clock belongs to neither state and survives both. It grows from the shut size to the
  // open one and slides onto the pill's centre line, so it is never seen to be replaced. On
  // the minute its digits roll to their next value; see Ui/RollingClock.qml.
  RollingClock {
    id: clockLabel

    // Set at the open size and scaled down rather than animating its pixel size, so the
    // digits are laid out once and the advance between them never shifts.
    readonly property real shownSize: Theme.islandClockSize + root.openness * (Theme.islandDisplaySize - Theme.islandClockSize)

    // Slides from the shut row's clock slot to the open card's centre line, riding the same
    // openness that already carries its size.
    x: {
      var openX = (root.width - width) / 2;
      var shutX = root.collapsedClockLeft - width * (1 - scale) / 2;
      return shutX + root.openness * (openX - shutX);
    }
    y: root.midline - 8 * root.openness - height / 2
    transformOrigin: Item.Center
    scale: shownSize / Theme.islandDisplaySize
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.islandDisplaySize
    font.weight: Font.DemiBold
  }

  // Sits over the clock and its date, and only takes clicks once the card is open.
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
