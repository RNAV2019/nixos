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

  // Raised around a change of level while the OSD is up, so each window turns the one before into
  // the new one (IslandSurfaceBase.swapBegin/swapEnd).
  signal swapping
  signal swapped

  // Up while one level is being replaced by another: the reading, glyph and ink then change
  // with the content swap and not on motions of their own.
  property bool modeSwapping: false

  function flash(which) {
    if (blocked)
      return;
    if (showing && mode !== which) {
      modeSwapping = true;
      root.swapping();
      mode = which;
      root.swapped();
      modeSwapping = false;
    } else {
      mode = which;
    }
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

      Connections {
        target: root

        function onSwapping() {
          window.swapBegin();
        }

        function onSwapped() {
          window.swapEnd();
        }
      }

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
        id: pill

        // Within one level, while the pill is up, a change is animated: the digits roll, the
        // glyph turns over and the ink tints. None of it queues behind a held key: each takes
        // the newest value at once.
        readonly property bool animated: window.open && !root.modeSwapping

        // A cross-fade caught by the pill shutting or the level changing lands at once.
        onAnimatedChanged: {
          if (!animated) {
            glyphFade.stop();
            glyphMix = 1;
          }
        }

        property color ink: root.ink

        Behavior on ink {
          enabled: pill.animated

          Tint {}
        }

        // The glyph cross-fade's clock, and the path it last settled on.
        property real glyphMix: 1
        property string shownGlyph: ""

        NumberAnimation {
          id: glyphFade

          target: pill
          property: "glyphMix"
          from: 0
          to: 1
          duration: Theme.duration(Theme.morphState)
          easing.type: Easing.OutCubic
        }

        x: window.surface.snap((parent.width - width) / 2)
        // The same level as the control centre's slider for it, which this turns into and out of;
        // else a pill like any other (a moment's, the sharing pill).
        morphKey: "level." + root.mode + "|pill"
        y: (parent.height - height) / 2
        layout: "glyphTrackReading"
        alert: root.current.alarming
        reading: root.current.reading
        readingColor: pill.ink
        rollReading: true
        rollPaused: root.modeSwapping
        value: root.current.value
        showFill: !root.current.stateOnly
        fillDuration: Theme.morphFill
        running: window.open

        StrokeIcon {
          anchors.centerIn: parent
          size: Theme.islandPillGlyphSize
          path: root.current.glyph
          color: pill.ink
          opacity: pill.glyphMix
          scale: Theme.glyphSwapDip + (1 - Theme.glyphSwapDip) * pill.glyphMix

          // A new glyph for the same level (the speaker gaining a wave, or its cross) fades in
          // over the one before, both dipping a little; a restart mid-fade starts from the newest.
          onPathChanged: {
            var before = pill.shownGlyph;
            pill.shownGlyph = path;
            if (!pill.animated || Theme.reduceMotion) {
              glyphFade.stop();
              pill.glyphMix = 1;
              return;
            }
            glyphBefore.path = before;
            glyphFade.restart();
          }
        }

        // The glyph on its way out, only there during the cross-fade.
        StrokeIcon {
          id: glyphBefore

          readonly property bool morphIgnore: true

          anchors.centerIn: parent
          size: Theme.islandPillGlyphSize
          color: pill.ink
          opacity: 1 - pill.glyphMix
          scale: 1 - (1 - Theme.glyphSwapDip) * pill.glyphMix
          visible: opacity > 0
        }
      }
    }
  }
}
