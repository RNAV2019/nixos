import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The on-screen displays: the island grows from its collapsed pill into a fixed 278 px
// pill, contents laid out at final positions from the first frame. Clicks pass through.
Scope {
  id: root

  readonly property int startupGrace: 1500

  // "", "volume", "brightness", "kbd" or "mic".
  property string mode: ""
  property bool showing: false
  signal flashRequested

  // Suppress startup signals without discarding the first later change.
  property bool ready: false

  Timer {
    running: true
    interval: root.startupGrace
    onTriggered: root.ready = true
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var sinkAudio: sink ? sink.audio : null
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var sourceAudio: source ? source.audio : null

  readonly property real volume: sinkAudio ? sinkAudio.volume : 0
  readonly property bool muted: sinkAudio ? sinkAudio.muted : false
  readonly property bool micMuted: sourceAudio ? sourceAudio.muted : false

  PwObjectTracker {
    objects: {
      var out = [];
      if (root.sink)
        out.push(root.sink);
      if (root.source)
        out.push(root.source);
      return out;
    }
  }

  // A user-opened panel owns the pill, so no OSD starts under one; a flash is cut short.
  readonly property bool blocked: Bus.islandHeld

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
    flashRequested();
    showing = true;
    hideTimer.restart();
  }

  onVolumeChanged: if (ready)
    flash("volume")

  onMutedChanged: if (ready)
    flash("volume")

  onMicMutedChanged: if (ready)
    flash("mic")

  // Keypresses at a rail move nothing, so adjusted covers them; value changes show too.
  Connections {
    target: Brightness

    function onAdjusted() {
      root.flash("brightness");
    }

    function onValueChanged() {
      // available filters the initial zero-to-real transition.
      if (root.ready && Brightness.available)
        root.flash("brightness");
    }
  }

  Connections {
    target: Volume

    function onAdjusted() {
      root.flash("volume");
    }
  }

  // Firmware handles the keyboard backlight key, so sysfs is its only signal.
  Connections {
    target: KeyboardBacklight

    function onLevelChanged() {
      if (root.ready && KeyboardBacklight.available)
        root.flash("kbd");
    }
  }

  Timer {
    id: hideTimer

    interval: Theme.osdDwell
    onTriggered: root.showing = false
  }

  readonly property real level: {
    if (mode === "brightness")
      return Brightness.value;
    if (mode === "kbd")
      return KeyboardBacklight.value;
    return volume;
  }

  // Mute is a state, not a level, so the bar carries no fill for it.
  readonly property bool stateOnly: (mode === "volume" && muted) || mode === "mic"

  readonly property string glyph: {
    if (mode === "brightness")
      return Icons.brightness;
    if (mode === "kbd")
      return Icons.keyboardBacklight;
    if (mode === "mic")
      return root.micMuted ? Icons.microphoneMuted : Icons.microphone;
    if (muted)
      return Icons.volumeMuted;
    return Icons.step(Icons.volume, volume * 100);
  }

  readonly property string reading: {
    if (mode === "mic")
      return root.micMuted ? "Mic off" : "Mic on";
    if (mode === "volume" && muted)
      return "Muted";
    return Math.round(Math.max(0, Math.min(1, level)) * 100) + "%";
  }

  // A hot microphone must not be misread, so it takes its own colour.
  readonly property bool alarming: mode === "mic" && root.micMuted

  readonly property color ink: {
    if (alarming)
      return Theme.urgent;
    if (stateOnly)
      return Theme.muted;
    return Theme.text;
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window

      required property var modelData

      readonly property bool focused: Monitors.isFocused(window.screen)

      readonly property int collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

      readonly property bool open: root.showing && focused && !outputBlocked

      // Drawn from the start of growth until back to pill size, keeping the island hidden.
       readonly property bool visibleNow: open || origin.held || surface.width > collapsedWidth + 0.5
       readonly property bool outputBlocked: Bus.islandHeldFor(window.screen ? window.screen.name : "")

        IslandOrigin {
          id: origin

          window: window
        }

        onOpenChanged: {
          if (!open && !origin.held)
            origin.release();
        }

       Connections {
         target: root

         function onFlashRequested() {
           if (window.focused && !window.outputBlocked)
             origin.claim(Theme.osdWidth, Theme.osdHeight, Theme.osdRadius, Theme.morphSurface);
         }
       }

       Connections {
         target: Bus

         function onSurfacesClosingForLock() {
           root.showing = false;
         }

         function onIslandClaimed(screen) {
           if (!window.open || !window.screen || screen !== window.screen.name)
             return;
           origin.publish(surface.width, surface.height, surface.surfaceRadius);
           origin.hold(surface.width, surface.height, surface.surfaceRadius);
           root.showing = false;
         }
       }

      screen: modelData
       visible: !Bus.locking && visibleNow
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-osd"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: Theme.barMarginTop + Theme.osdHeight + Theme.gapsOut
      exclusionMode: ExclusionMode.Ignore

      // Empty: the whole window is click-through. The island underneath still wants its clicks.
      mask: Region {}

        onVisibleNowChanged: {
         if (visibleNow)
           Bus.setTransientScreen("osd", window.screen ? window.screen.name : "");
         else if (window.screen && Bus.transientScreen("osd") === window.screen.name)
           Bus.setTransientScreen("osd", "");
       }

      FrostedSurface {
        id: surface

        x: (window.width - width) / 2
        y: Theme.barMarginTop

        clipContent: true

       implicitWidth: window.open ? Theme.osdWidth : origin.held ? origin.heldWidth : origin.originWidth
       implicitHeight: window.open ? Theme.osdHeight : origin.held ? origin.heldHeight : origin.originHeight

        // Read off the height rather than travelling; see Bar/Island.qml.
        surfaceRadius: Math.min(height / 2, Theme.osdRadius)

       Behavior on implicitWidth {
         enabled: !Theme.reduceMotion

         SurfaceSpring {}
       }

       Behavior on implicitHeight {
         enabled: !Theme.reduceMotion

         SurfaceSpring {}
       }

        // Shared collapsed renderer, so handoff keeps the same clock, equaliser and recording mark.
        CollapsedPill {
          id: pill

          anchors.fill: parent
          origin: origin
          shown: !window.open && !origin.held
        }

        // Board 09's row, at the board's own positions; nothing here moves with the shape.
        Item {
          id: readout

          anchors.fill: parent
          opacity: window.open ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent
            }
          }

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
                  duration: 80
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
          radius: surface.surfaceRadius
          color: "transparent"
          border.width: 1.5
          border.color: Theme.withAlpha(Theme.urgent, 0.7)
          opacity: root.alarming && window.open ? 1 : 0
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
}
