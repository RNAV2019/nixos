import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Commons
import qs.Services

Scope {
  id: root

  readonly property int dwell: 1500
  readonly property int startupGrace: 1500

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

  readonly property real volume: sinkAudio ? sinkAudio.volume : 0
  readonly property bool muted: sinkAudio ? sinkAudio.muted : false

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  function flash(which) {
    mode = which;
    showing = true;
    hideTimer.restart();
  }

  onVolumeChanged: {
    if (ready)
      flash("volume");
  }

  onMutedChanged: {
    if (ready)
      flash("volume");
  }

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
    interval: root.dwell
    onTriggered: root.showing = false
  }

  readonly property real level: {
    if (mode === "brightness")
      return Brightness.value;
    if (mode === "kbd")
      return KeyboardBacklight.value;
    return volume;
  }

  // Every glyph the OSD can show, used to size a stable icon column.
  readonly property var glyphCandidates: Icons.volume.concat([Icons.volumeMuted, Icons.brightness, Icons.keyboardBacklight])

  readonly property string glyph: {
    if (mode === "brightness")
      return Icons.brightness;
    if (mode === "kbd")
      return Icons.keyboardBacklight;
    if (muted)
      return Icons.volumeMuted;
    return Icons.step(Icons.volume, volume * 100);
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window

      required property var modelData

      readonly property bool focused: Monitors.isFocused(window.screen)

      screen: modelData
      visible: root.showing && focused
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-osd"

      anchors {
        bottom: true
      }

      margins.bottom: 120
      implicitWidth: 260
      implicitHeight: 48
      exclusionMode: ExclusionMode.Ignore

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.withAlpha(Theme.base, 0.95)
        border.width: 1
        border.color: Theme.highlightMed

        // Glyph widths differ between icon sets and across volume steps, which
        // slid the progress bar sideways as the level crossed a threshold. Pin
        // the column to the widest candidate. The probes overlap at x=0, so
        // childrenRect spans the widest one rather than their total.
        Item {
          id: glyphProbe

          visible: false

          Repeater {
            model: root.glyphCandidates

            Text {
              required property string modelData

              text: modelData
              font.family: Theme.iconFont
              font.pixelSize: Theme.fontSizeXl
            }
          }
        }

        Item {
          id: osdIcon

          anchors.left: parent.left
          anchors.leftMargin: Theme.spacingXl
          anchors.verticalCenter: parent.verticalCenter
          width: glyphProbe.childrenRect.width
          height: parent.height

          Text {
            anchors.centerIn: parent
            text: root.glyph
            color: Theme.text
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeXl
          }
        }

        Rectangle {
          anchors.left: osdIcon.right
          anchors.leftMargin: Theme.spacingLg
          anchors.right: parent.right
          anchors.rightMargin: Theme.spacingXl
          anchors.verticalCenter: parent.verticalCenter
          height: 6
          radius: height / 2
          color: Theme.overlay

          Rectangle {
            width: Math.max(0, Math.min(1, root.level)) * parent.width
            height: parent.height
            radius: parent.radius
            color: root.mode === "volume" && root.muted ? Theme.muted : Theme.accent

            // Held keys repeat about every 40 ms, so a longer tween never
            // finishes and the fill visibly trails the key.
            Behavior on width {
              NumberAnimation {
                duration: 80
              }
            }
          }
        }
      }
    }
  }
}
