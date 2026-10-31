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

      function onAdjusted() {
        if (root.ready)
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

  readonly property real level: current.value
  readonly property bool stateOnly: current.stateOnly
  readonly property string glyph: current.glyph
  readonly property string reading: current.reading
  readonly property bool alarming: current.alarming

  readonly property color ink: {
    if (alarming)
      return Theme.urgent;
    if (stateOnly)
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

      openWidth: Theme.osdWidth
      openHeight: Theme.osdHeight
      openRadius: Theme.osdRadius

      // The whole window is click-through. The island underneath still wants its clicks.
      cardInput: false

      // A panel taking the island cuts the flash short.
      onDismissed: {
        hideTimer.stop();
        root.showing = false;
      }

      // Board 09's row, at the board's own positions; nothing here moves with the shape.
      Item {
        id: readout

        anchors.fill: parent

        Text {
          x: Theme.osdGlyphLeft
          y: (Theme.osdHeight - height) / 2
          text: root.glyph
          color: root.ink
          font.family: Theme.iconFont
          font.pixelSize: Theme.osdGlyphSize
        }

        Rectangle {
          x: Theme.osdTrackLeft
          y: (Theme.osdHeight - height) / 2
          width: Theme.osdTrackWidth
          height: Theme.osdTrackHeight
          radius: height / 2
          color: Theme.highlightLow

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.level))
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            visible: !root.stateOnly

            // Held keys repeat about every 40 ms, so a longer tween never finishes.
            Behavior on width {
              NumberAnimation {
                duration: Theme.morphFill
              }
            }
          }
        }

        Text {
          x: Theme.osdWidth - Theme.osdValueRight - width
          y: (Theme.osdHeight - height) / 2
          text: root.reading
          color: root.ink
          font.family: Theme.uiFont
          font.pixelSize: Theme.osdValueSize
          font.weight: Theme.weightSemi
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: window.surface.surfaceRadius
        color: "transparent"
        border.width: 1.5
        border.color: Theme.withAlpha(Theme.urgent, 0.7)
        opacity: root.alarming ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent
          }
        }
      }
    }
  }
}
