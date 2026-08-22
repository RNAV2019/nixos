import QtQuick
import Quickshell
import Quickshell.Hyprland
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

  Connections {
    target: Brightness

    function onValueChanged() {
      // available filters the initial zero-to-real transition.
      if (root.ready && Brightness.available)
        root.flash("brightness");
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

      readonly property bool focused: Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === window.screen.name

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

        Text {
          id: osdIcon
          anchors.left: parent.left
          anchors.leftMargin: Theme.spacingXl
          anchors.verticalCenter: parent.verticalCenter
          text: root.glyph
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeXl
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

            Behavior on width {
              NumberAnimation {
                duration: Theme.animFast
              }
            }
          }
        }
      }
    }
  }
}
