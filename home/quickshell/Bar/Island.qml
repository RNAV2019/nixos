import QtQuick
import Quickshell
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The centred surface, the only one that changes shape. The open is not a cross-fade: contents
// scale with the pill and the track block clips, revealing the title letter by letter.
FrostedSurface {
  id: root

  // The three cross-fades between shut pill and open card share one duration.
  component Fade: Morph {
    duration: Theme.morphContent
  }

  // A pin holds the card open after the pointer leaves; clicking again drops it.
  property bool pinned: false

  // The output this island is on; the card is a bar item, so a surface growing out of it
  // matches against this. See Ui/IslandOrigin.qml.
  property string screenName: ""

  // Raised while another surface covers the island; it stays mapped for handoff timing
  // but is not painted while the covering surface samples the desktop.
  property bool suppressed: false

  // Whether the covering surface stays: the launcher and control centre drop a pin so the
  // card is not found open underneath; the OSD does not, since a volume key should not close it.
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

  // Opening is quick; closing has hysteresis so a pointer crossing the pill's edge does not
  // flicker the card shut.
  Timer {
    id: openDelay

    interval: Theme.islandHoverOpenDelay
    onTriggered: if (!root.suppressed && hover.containsMouse)
      root.hoverOpen = true
  }

  Timer {
    id: closeGrace

    interval: Theme.islandHoverCloseDelay
    onTriggered: if (!root.suppressed && !hover.containsMouse && !root.pinned)
      root.hoverOpen = false
  }

  onPinnedChanged: {
    if (suppressed)
      return;
    if (pinned) {
      closeGrace.stop();
      hoverOpen = true;
    } else if (!hover.containsMouse) {
      closeGrace.restart();
    }
  }

  // Offer the card to whatever might grow out of it; only one island is under the pointer,
  // so only one is ever on offer.
  onExpandedChanged: {
    if (expanded)
      Bus.setIslandCard(root.screenName, root);
    else if (Bus.islandCardFor(root.screenName) === root)
      Bus.setIslandCard(root.screenName, null);
  }

  clipContent: true

  readonly property int collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

  implicitWidth: expanded ? Theme.islandExpandedWidth : collapsedWidth
  implicitHeight: targetHeight

  // Corner read off height, not animated: a per-frame fit gives radius = min(height / 2,
  // surface radius) to 1.25 px rms vs 5.32 px interpolated, keeping a true stadium longer.
  surfaceRadius: Math.min(height / 2, Theme.islandExpandedRadius)

  Behavior on implicitWidth {
    id: widthBehavior
    enabled: !Theme.reduceMotion

    SurfaceSpring {
      id: widthSpring
    }
  }

  Behavior on implicitHeight {
    id: heightBehavior
    enabled: !Theme.reduceMotion

    SurfaceSpring {
      id: heightSpring
    }
  }

  readonly property real targetHeight: expanded ? Theme.islandExpandedHeight : Theme.barHeight
  readonly property bool morphRunning: widthSpring.running || heightSpring.running

  // The card is sized against the pill's height, so one animated property carries the layout
  // and nothing falls out of step with the shape.
  readonly property real scaleFactor: height / Theme.islandExpandedHeight

  // Progress 0 shut, 1 open, for things that travel between two fixed states rather than scale.
  readonly property real openness: {
    var span = Theme.islandExpandedHeight - Theme.barHeight;
    return span <= 0 ? 1 : Theme.clamp01((height - Theme.barHeight) / span);
  }

  readonly property real midline: height / 2

  // The clock is drawn at open size and scaled, so its shown left edge differs from its
  // unscaled box; everything stopping short of the clock measures against this.
  readonly property real clockLeft: clockLabel.x + clockLabel.width * (1 - clockLabel.scale) / 2

  // The date is wider than the clock, so while the card is small the track block stops short
  // of the date.
  readonly property real centreLeft: Math.min(clockLeft, date.x + date.width * (1 - date.scale) / 2)

  // Do not infer completion from clamped openness; a spring may cross the target before resting.
  readonly property bool settled: !morphRunning && Math.abs(height - targetHeight) < 0.5

  // The shut pill is one row on 34 px margins; every board width is that row plus 68. The
  // equaliser shoulder and dot differ, so the clock shifts; see Theme.islandCollapsedWidth.
  readonly property real collapsedGap: 7.5

  // Where the shut row puts the clock's shown left edge, measured as clockLeft measures it.
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

  // Clicking empty island space pins the card open; controls on top act without disturbing it.
  MouseArea {
    id: hover

    anchors.fill: parent
    enabled: !root.suppressed
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

  // The recording mark, trailing the clock so the equaliser keeps its place. Shown only while
  // shut: a red dot in the open card would be a second subject.
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
      Fade {}
    }
  }

  // The shut pill's equaliser; the open card has its own, so this one hands over.
  Equaliser {
    id: collapsedEq

    x: root.clockLeft - root.collapsedGap - implicitWidth
    y: root.midline - implicitHeight / 2
    playing: Media.playing
    visible: Media.active && opacity > 0
    opacity: root.expanded ? 0 : 1

    Behavior on opacity {
      Fade {}
    }
  }

  // Card laid out against the pill's live width, which makes contents reflow as it opens.
  Item {
    id: card

    anchors.fill: parent
    opacity: root.expanded ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Fade {}
    }

    // One scaled frame carries every block drawn at open metrics: placing the children here
    // keeps one transform instead of four, and their x/y are the open-card coordinates (the
    // composite TopLeft scaling lands each block exactly where its hand-placed form sat).
    Item {
      id: scaledCard

      x: 0
      y: 0
      width: root.scaleFactor > 0 ? root.width / root.scaleFactor : 0
      height: Theme.islandExpandedHeight
      transformOrigin: Item.TopLeft
      scale: root.scaleFactor

      // Track block drawn once at open metrics and scaled, clipped rather than elided; animating
      // font size re-fits glyphs every frame and the trailing letters flicker against the ellipsis.
      Item {
        id: media

        x: 16
        y: 0
        width: root.scaleFactor > 0 ? Math.max(0, (root.centreLeft - 28 * root.scaleFactor) / root.scaleFactor) : 0
        height: Theme.islandExpandedHeight
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

      // With nothing playing the track block's room carries the week instead, drawn from the
      // card's left inset and scaled like the block it replaces, so the strip grows with the pill.
      MiniCalendar {
        x: 16
        y: (parent.height - height) / 2
        today: clock.date
        visible: !Media.active
      }

      // Board 02's gauges: the battery 16 px in from the right like the album art, system load
      // beside it. Their x rides the pill's live width, so the right inset is scaled off.
      SystemGauge {
        x: root.scaleFactor > 0 ? root.width / root.scaleFactor - 16 - 12 - 2 * implicitWidth : 0
        y: (parent.height - height) / 2
      }

      StatusGauge {
        x: root.scaleFactor > 0 ? root.width / root.scaleFactor - 16 - implicitWidth : 0
        y: (parent.height - height) / 2
      }
    }

    // Left/right buttons skip, so the card is a transport as well as a readout; kept outside
    // the scaled block so it stays in real coordinates.
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
  }

  // The clock belongs to neither state and survives both, growing from the shut size and
  // sliding onto the centre line so it is never seen replaced; see Ui/RollingClock.qml.
  RollingClock {
    id: clockLabel

    // Set at the open size and scaled down rather than animating pixel size, so the digits are
    // laid out once and the advance between them never shifts.
    readonly property real shownSize: Theme.islandClockSize + root.openness * (Theme.islandDisplaySize - Theme.islandClockSize)

    // Slides from the shut clock slot to the open centre line, riding the same openness that
    // already carries its size.
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
}
