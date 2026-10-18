import QtQuick
import qs.Commons
import qs.Services

// The one collapsed renderer used by transient surfaces and handoff stills, so a surface
// never hands back a subtly different pill than the bar owns.
Item {
  id: root

  property bool mediaActive: Media.active
  property bool playing: Media.playing
  property bool recording: Recorder.recording
  property bool camera: Privacy.camera
  property bool microphone: Privacy.microphone
  property bool shown: true
  property real clockShift: 0
  property var origin: null

  Accessible.ignored: true

  // Cut rather than faded, as the clock is: a shape from another surface had no pill showing,
  // a still is going, and the drop well had hidden all three.
  readonly property bool cut: root.origin !== null && (root.origin.handedOver || root.origin.held || !root.origin.fromClock)

  // Centred, as the bar pill's clock is: the marks are balanced either side of it.
  IslandClock {
    id: clock

    anchors.fill: parent
    origin: root.origin
    shown: root.shown
    clockShift: root.clockShift
  }

  PillMarks {
    anchors.fill: parent
    clockLeft: parent.width / 2 + root.clockShift - clock.clockWidth / 2
    clockRight: parent.width / 2 + root.clockShift + clock.clockWidth / 2
    mediaActive: root.mediaActive
    playing: root.playing
    recording: root.recording
    camera: root.camera
    microphone: root.microphone
    visible: leftExtent + rightExtent > 0 && opacity > 0
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
      enabled: !root.cut

      Morph { duration: Theme.morphContent }
    }
  }
}
