import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The on-screen displays: the island grows from its collapsed pill into a fixed 278 px
// pill, contents laid out at final positions from the first frame. Clicks pass through.
Scope {
  id: root

  // "", "volume", "brightness", "kbd" or "mic".
  property string mode: ""
  property bool showing: false

  // Suppress startup signals without discarding the first later change.
  property bool ready: false

  Timer {
    running: true
    interval: Theme.osdDwell
    onTriggered: root.ready = true
  }

  readonly property var sources: ({
      "volume": Volume,
      "brightness": Brightness,
      "kbd": KeyboardBacklight,
      "mic": Microphone
    })

  // Before the first flash the pill is shut, so Volume only stands in for a mode of "".
  readonly property var current: sources[mode] ?? Volume

  // A user-opened panel owns the pill, so no OSD starts under one; a flash is cut short.
  readonly property bool blocked: Bus.islandOpenAnywhere

  onBlockedChanged: {
    if (blocked) {
      hideTimer.stop();
      showing = false;
    }
  }

  function flash(which) {
    if (blocked)
      return;
    mode = which;
    showing = true;
    hideTimer.restart();
  }

  Instantiator {
    model: Object.keys(root.sources)

    Connections {
      required property string modelData

      target: root.sources[modelData]

      function onAdjusted(pressed) {
        if (root.ready || pressed)
          root.flash(modelData);
      }
    }
  }

  Connections {
    target: Bus

    function onSurfacesClosingForLock() {
      hideTimer.stop();
      root.showing = false;
    }
  }

  Timer {
    id: hideTimer

    interval: Theme.osdDwell
    onTriggered: root.showing = false
  }

  readonly property color ink: {
    if (current.alarming)
      return Theme.urgent;
    if (current.stateOnly)
      return Theme.muted;
    return Theme.text;
  }

  Variants {
    model: Quickshell.screens

    // Outranks the other transients: a keypress wants its answer now. A toast or the sharing
    // pill under it waits, and takes the island back from it once the flash is over.
    TransientSurface {
      id: window

      key: "osd"
      rank: 4

      readonly property bool outputBlocked: Bus.islandOpenFor(window.screenName)

      wanted: root.showing && window.focused && !window.outputBlocked

      openWidth: Theme.islandPillWidth
      openHeight: Theme.islandPillHeight
      openRadius: Theme.islandPillRadius

      // The whole window is click-through. The island underneath still wants its clicks.
      cardInput: false

      // A panel taking the island cuts the flash short.
      onDismissed: {
        hideTimer.stop();
        root.showing = false;
      }

      IslandPill {
        x: (window.surface.width - width) / 2
        y: (window.surface.height - height) / 2
        layout: "glyphTrackReading"
        alert: root.current.alarming
        reading: root.current.reading
        readingColor: root.ink
        value: root.current.value
        showFill: !root.current.stateOnly
        fillDuration: Theme.morphFill
        running: window.open

        Text {
          anchors.centerIn: parent
          text: root.current.glyph
          color: root.ink
          font.family: Theme.iconFont
          font.pixelSize: Theme.islandPillGlyphSize
        }
      }
    }
  }
}
