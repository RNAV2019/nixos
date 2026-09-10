import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The on-screen displays, and the island in its fourth shape.
//
// Board 09, and not a card floating over the desktop. Change the volume and the
// pill that was carrying the clock widens in place into a glyph, a bar and a
// reading, holds for a second and a half, and melts back into the clock. The
// source recording is unambiguous about this: between 3:05 and 3:20 there is
// never a second surface on screen, and one frame of the return catches the
// clock drawn back over the bar while the two cross-fade.
//
// So this is built like the launcher and the control centre. It starts at the
// island's own collapsed pill - the same width, height, radius and centre line,
// carrying the same equaliser and clock - and grows into a fixed 278 px pill
// whose contents are laid out at their final positions from the first frame.
// The bar stands its island down while this is up.
//
// Nothing here takes input. The window's mask is empty, so every click passes
// straight through to the island underneath rather than being eaten by an
// overlay the user cannot even see the edges of.
Scope {
  id: root

  readonly property int startupGrace: 1500

  // "", "volume", "brightness", "kbd" or "mic".
  property string mode: ""
  property bool showing: false

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

  // The launcher and the control centre are the island's other two shapes, and
  // they own the pill while they are open. An OSD has no business growing out
  // from under a 520 px panel that already covers the place it would appear in,
  // so it does not start while one is up, and a flash already in the air is cut
  // short by one opening.
  readonly property bool blocked: Bus.islandHeld

  onBlockedChanged: if (blocked) {
    hideTimer.stop();
    showing = false;
  }

  function flash(which) {
    if (blocked)
      return;
    mode = which;
    showing = true;
    hideTimer.restart();
  }

  onVolumeChanged: if (ready)
    flash("volume")

  onMutedChanged: if (ready)
    flash("volume")

  onMicMutedChanged: if (ready)
    flash("mic")

  // A keypress at either rail moves nothing, so the value signals below never
  // fire for it. adjusted covers the press itself; the value signals stay so
  // changes from elsewhere (idle dimming, the lock screen) still show.
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

  // Mute is a state, not a level, so the bar carries no fill for it. Board 09
  // draws the muted pill as a bare track with a word where the reading goes.
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

  // A hot microphone is the one state here you must not misread, so muting it
  // is the only OSD that takes a colour of its own.
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

      readonly property bool open: root.showing && focused

      // Drawn from the moment the shape starts growing until it is back to pill
      // size, which is the whole time the bar must keep its island hidden.
      readonly property bool visibleNow: open || surface.width > collapsedWidth + 0.5

      screen: modelData
      visible: visibleNow
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

      // Empty: the whole window is click-through. The island is underneath and
      // still wants its clicks.
      mask: Region {}

      onVisibleNowChanged: {
        if (visibleNow)
          Bus.osdScreen = window.screen ? window.screen.name : "";
        else if (window.screen && Bus.osdScreen === window.screen.name)
          Bus.osdScreen = "";
      }

      FrostedSurface {
        id: surface

        x: (window.width - width) / 2
        y: Theme.barMarginTop

        clipContent: true

        implicitWidth: window.open ? Theme.osdWidth : window.collapsedWidth
        implicitHeight: window.open ? Theme.osdHeight : Theme.barHeight

        // Read off the height rather than travelling; see Bar/Island.qml.
        surfaceRadius: Math.min(height / 2, Theme.osdRadius)

        Behavior on implicitWidth {
          Morph {}
        }

        Behavior on implicitHeight {
          Morph {}
        }

        IslandClock {
          id: clock

          anchors.fill: parent
          shown: !window.open
          clockShift: pill.clockShift
        }

        // The pill the OSD grows out of and shrinks back into, drawn exactly as
        // Bar/Island.qml draws its collapsed state: the clock on the centre
        // line, shifted right by half the equaliser when there is one, and the
        // equaliser to its left. It has to match, because this surface covers
        // the island rather than replacing it, and any disagreement between the
        // two would read as the pill jumping at both ends of the flash.
        Item {
          id: pill

          anchors.fill: parent
          opacity: window.open ? 0 : 1
          visible: opacity > 0

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent
            }
          }

          readonly property real collapsedGap: 7.5
          readonly property real clockShift: Media.active ? (equaliser.implicitWidth + collapsedGap) / 2 : 0
          Equaliser {
            id: equaliser

            x: parent.width / 2 + pill.clockShift - Theme.islandClockSize * 1.5 - pill.collapsedGap - implicitWidth
            y: (parent.height - implicitHeight) / 2
            playing: Media.playing
            visible: Media.active
          }

        }

        // Board 09's row, at the board's own positions in the board's own
        // 278 px pill. Nothing in here moves with the shape; the shape uncovers
        // it.
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

              // Held keys repeat about every 40 ms, so a longer tween never
              // finishes and the fill visibly trails the key.
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

        // Board 09 rings the microphone pill rather than only recolouring what
        // is inside it. FrostedSurface draws its own hairline, so this is laid
        // over the top of that one and fades in with the state.
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
