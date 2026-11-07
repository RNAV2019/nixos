import QtQuick
import Quickshell
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The centred surface, the only one that changes shape. The open is not a cross-fade and nothing
// scales but the clock: each block is drawn at its true size, rides the card's live edge, and
// flies in on its own stretch of the open (saneAspect's shared-element card), while the growing
// shape uncovers it and the track block clips, revealing the title letter by letter.
FrostedSurface {
  id: root

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

  // Back from under a closing surface, the pill's shadow fades in while that surface's fades out
  // (Ui/IslandSurfaceBase.qml), so for the frames both are on screen the two never stack.
  property real shadowLevel: suppressed ? 0 : 1
  shadowStrength: Theme.surfaceShadowAlpha * shadowLevel

  Behavior on shadowLevel {
    NumberAnimation {
      duration: Theme.duration(Theme.shadowHandover)
    }
  }

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
  readonly property bool expanded: !suppressed && !dropArmed && (pinned || hoverOpen)

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

  // Whenever the island is anything but the resting pill - open, on its way open or shut, or
  // the drop well - a surface taking its place grows out of the shape it is actually wearing,
  // not the pill it may be headed for. One output, one island, so only one is ever on offer.
  readonly property bool resting: Math.abs(heightSpring.value - Theme.barHeight) < 0.5 && Math.abs(widthSpring.value - collapsedWidth) < 0.5
  readonly property bool onOffer: !suppressed && (expanded || dropArmed || !resting)

  // Read by the surface growing out of this shape: the drop well has no clock up.
  readonly property bool clockShown: !dropArmed

  onOnOfferChanged: {
    if (onOffer)
      Bus.setIslandCard(root.screenName, root);
    else if (Bus.islandCardFor(root.screenName) === root)
      Bus.setIslandCard(root.screenName, null);
  }

  clipContent: true

  // Board 16e: a file drag turns the pill into a 248 x 52 drop well. The well arms after a
  // 50 ms hover and unwinds after a 40 ms grace; a drop on the pill opens the Nearby panel in
  // Send mode with the files already staged.
  property bool dropArmed: false

  Timer {
    id: dragArm

    interval: 50
    onTriggered: root.dropArmed = true
  }

  Timer {
    id: dragGrace

    interval: 40
    onTriggered: root.dropArmed = false
  }

  DropArea {
    id: fileDrop

    z: 100
    anchors.fill: parent
    enabled: !root.suppressed && !root.expanded

    // Only file drags arm the well; other drags (e.g. a browser tab) have nothing to send.
    function hasFiles(urls) {
      for (var i = 0; i < urls.length; i++)
        if (String(urls[i]).startsWith("file:"))
          return true;
      return false;
    }

    onEntered: function (drag) {
      if (!hasFiles(drag.urls))
        return;
      dragArm.restart();
      dragGrace.stop();
    }

    onExited: {
      dragArm.stop();
      if (root.dropArmed)
        dragGrace.restart();
    }

    // The panel is asked for while the well is still up, so it grows out of the well's own
    // shape; the island only unwinds after, under the panel. Any drop ends the drag, so the
    // well always unwinds, even when there was nothing to send.
    onDropped: function (drop) {
      dragArm.stop();
      dragGrace.stop();
      if (hasFiles(drop.urls)) {
        Nearby.requestSend(Nearby.pathsFromUrls(drop.urls));
        drop.acceptProposedAction();
      }
      root.dropArmed = false;
    }
  }

  readonly property int collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording, Privacy.camera, Privacy.microphone)

  // On the same spring as every surface that grows out of it; see Ui/MorphSpring.qml.
  MorphSpring {
    id: widthSpring

    label: "island.w"
    target: root.dropArmed ? Theme.nearbyDropTargetWidth : root.expanded ? Theme.islandExpandedWidth : root.collapsedWidth
  }

  MorphSpring {
    id: heightSpring

    label: "island.h"
    target: root.targetHeight
  }

  implicitWidth: widthSpring.value
  implicitHeight: heightSpring.value

  // The right edge as the springs have it, centred as the bar centres the pill but not rounded
  // to the pixel grid: x and width snap separately, so their sum jitters by a device pixel on
  // the way. The phone satellite rides this.
  readonly property real edgeX: ((parent ? parent.width : 0) + widthSpring.value) / 2 + Bus.pillOffsetX

  // Corner read off height, not animated: a per-frame fit gives radius = min(height / 2,
  // surface radius) to 1.25 px rms vs 5.32 px interpolated, keeping a true stadium longer.
  surfaceRadius: Math.min(height / 2, Theme.islandExpandedRadius)

  readonly property real targetHeight: dropArmed ? Theme.nearbyDropTargetHeight : expanded ? Theme.islandExpandedHeight : Theme.barHeight
  readonly property bool morphRunning: widthSpring.running || heightSpring.running

  // Progress 0 shut, 1 open, read off the shape's height, so nothing falls out of step with it;
  // the spring's small overshoot is clamped away.
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
  readonly property real centreLeft: Math.min(clockLeft, date.x)

  // A block's own stretch of the open, eased: 0 until `openness` reaches `from`, 1 once it reaches
  // `to`. Staggered stretches make the blocks arrive one after another and, the spring running
  // back, leave in the reverse order.
  function reveal(from, to) {
    var t = Theme.clamp01((openness - from) / (to - from));
    return t * t * (3 - 2 * t);
  }

  // How far a block travels as it arrives, from towards the clock.
  readonly property real flight: 14

  // The week and the gauges sit beside the clock, so they wait until the card is wide enough to
  // hold them whole (about 0.7 of the open; earlier, half of each is cut off at the clock) and
  // then fade in with a short drift. Closing, they are the first to go.
  readonly property real sideFrom: 0.7
  readonly property real sideTo: 0.97
  readonly property real sideFlight: 6

  // Do not infer completion from clamped openness; a spring may cross the target before resting.
  readonly property bool settled: !morphRunning && Math.abs(height - targetHeight) < 0.5

  // Where the shut pill puts the clock's shown left edge, measured as clockLeft measures it:
  // always centred, the marks being balanced either side; see Theme.islandCollapsedWidth.
  readonly property real collapsedClockLeft: (root.width - clockLabel.width * clockLabel.scale) / 2

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  Connections {
    target: Bus

    function onClockRefreshed() {
      clock.enabled = false;
      clock.enabled = true;
    }
  }

  // Clicking empty island space pins the card open; controls on top act without disturbing it.
  MouseArea {
    id: hover

    anchors.fill: parent
    enabled: !root.suppressed && !root.dropArmed
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

  // The equaliser, recording and privacy marks either side of the clock. Shown only while
  // shut: the open card has its own equaliser, and the other marks there would be a second
  // subject.
  PillMarks {
    x: 0
    y: root.midline - height / 2
    width: root.width
    height: Theme.barHeight
    clockLeft: root.clockLeft
    clockRight: root.clockLeft + clockLabel.width * clockLabel.scale
    visible: leftExtent + rightExtent > 0 && opacity > 0
    opacity: root.expanded || root.dropArmed ? 0 : 1

    Behavior on opacity {
      ContentFade {}
    }
  }

  // The card's blocks at their open size, each riding the card's live edge (the track block and
  // the week the left, the gauges the right) and centred on its live midline, so the growing shape
  // uncovers them rather than scaling them. Hidden for the drop well, which has no card.
  Item {
    id: card

    anchors.fill: parent
    opacity: root.dropArmed ? 0 : 1
    visible: opacity > 0 && root.openness > 0

    Behavior on opacity {
      ContentFade {}
    }

    // Track block clipped rather than elided while it moves; animating font size re-fits glyphs
    // every frame and the trailing letters flicker against the ellipsis.
    Item {
      id: media

      x: 16
      y: root.midline - height / 2
      width: Math.max(0, root.centreLeft - 28 - x)
      height: Theme.islandExpandedHeight
      clip: true
      visible: Media.active

      AlbumArt {
        id: cover

        readonly property real shown: root.reveal(0.1, 0.55)

        x: -root.flight * (1 - shown)
        y: (parent.height - height) / 2
        width: Theme.islandArtSize
        height: width
        opacity: shown
      }

      Equaliser {
        id: cardEq

        x: 60 - root.flight * (1 - cover.shown)
        y: (parent.height - height) / 2
        playing: Media.playing
        opacity: cover.shown
      }

      Item {
        id: track

        readonly property real shown: root.reveal(0.3, 0.8)

        x: 84 - root.flight * (1 - shown)
        width: Math.max(0, parent.width - 84)
        height: parent.height
        opacity: shown

        Text {
          id: title

          y: parent.height / 2 - 8 - height / 2
          width: parent.width
          // Only once the morph stops, so the ellipsis never appears mid-motion.
          elide: root.settled ? Text.ElideRight : Text.ElideNone
          text: Media.title
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.islandTitleSize
          font.weight: Theme.weightSemi
        }

        Text {
          y: parent.height / 2 + 9.5 - height / 2
          width: parent.width
          elide: root.settled ? Text.ElideRight : Text.ElideNone
          text: Media.artist
          color: Theme.subtle
          font.family: Theme.uiFont
          font.pixelSize: Theme.islandCaptionSize
        }
      }
    }

    // With nothing playing the track block's room carries the week instead, from the same
    // left inset, clipped short of the clock like the track block.
    Item {
      x: 16
      width: Math.max(0, root.centreLeft - 12 - x)
      height: parent.height
      clip: true
      visible: !Media.active

      MiniCalendar {
        readonly property real shown: root.reveal(root.sideFrom, root.sideTo)

        x: -root.sideFlight * (1 - shown)
        y: root.midline - height / 2
        today: clock.date
        opacity: shown
      }
    }

    // Board 02's gauges: the battery 16 px in from the right like the album art, system load
    // beside it, fading in once the card can hold them (sideFrom). Clipped short of the clock on
    // that side too, so nothing crosses it.
    Item {
      id: gauges

      x: root.width - root.centreLeft + 12
      width: Math.max(0, root.width - x)
      height: parent.height
      clip: true

      SystemGauge {
        readonly property real shown: root.reveal(root.sideFrom, root.sideTo)

        x: gauges.width - 16 - 12 - 2 * width + root.sideFlight * (1 - shown)
        y: root.midline - height / 2
        opacity: shown
      }

      StatusGauge {
        readonly property real shown: root.reveal(root.sideFrom, root.sideTo)

        x: gauges.width - 16 - width + root.sideFlight * (1 - shown)
        y: root.midline - height / 2
        opacity: shown
      }
    }

    // Left/right buttons skip, so the card is a transport as well as a readout.
    MouseArea {
      x: 0
      y: 0
      width: Math.max(0, root.centreLeft - 12)
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

    // The date arrives last, rising into place under the clock as it settles.
    Text {
      id: date

      readonly property real shown: root.reveal(0.5, 0.95)

      x: (root.width - width) / 2
      y: root.midline + 13.5 - height / 2 + 6 * (1 - shown)
      opacity: shown
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

    // Gives way to the drop well on the same cross-fade as the rest of the pill.
    opacity: root.dropArmed ? 0 : 1
    visible: opacity > 0

    Behavior on opacity {
      ContentFade {}
    }

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
    font.weight: Theme.weightSemi
  }

  // The drop well (board 16e): a dashed well on the pill's surface, ringed in accent. Fades
  // both ways; tied to its own opacity, not the arm, so the way out is not a cut.
  Item {
    anchors.fill: parent
    opacity: root.dropArmed ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      ContentFade {}
    }

    Rectangle {
      x: Theme.nearbyDropWellInset
      y: Theme.nearbyDropWellInset
      width: root.width - Theme.nearbyDropWellInset * 2
      height: Theme.nearbyDropWellHeight
      radius: Theme.nearbyDropWellRadius
      color: Theme.withAlpha(Theme.accentFill, 0.12)

      DashedOutline {
        anchors.fill: parent
        anchors.margins: 1
        cornerRadius: Theme.nearbyDropWellRadius
        strokeWidth: Theme.nearbyDropWellStroke
        strokeColor: Theme.withAlpha(Theme.accentFill, 0.7)
      }
    }

    StrokeIcon {
      anchors.centerIn: parent
      size: Theme.nearbyDropWellGlyph
      strokeWidth: 1.8
      path: IconPaths.download
      color: Theme.accentFill
    }

    Rectangle {
      anchors.fill: parent
      radius: root.surfaceRadius
      color: "transparent"
      border.width: Theme.nearbyDropStroke
      border.color: Theme.withAlpha(Theme.accentFill, 0.55)
    }
  }
}
