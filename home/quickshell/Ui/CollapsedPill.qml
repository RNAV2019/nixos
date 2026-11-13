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
  // Closing, how far the clock and marks have arrived (0..1), read off the closing surface's
  // shape progress; while `progressDriven`, this replaces the timed fade of `shown`.
  property bool progressDriven: false
  property real amount: 1
  property real clockShift: 0
  property var origin: null

  // The clock's width as drawn and the time it shows, for what is laid out against it (the
  // open card's date and gauges, Ui/IslandSurfaceBase.qml).
  readonly property real clockWidth: clock.clockWidth
  readonly property date clockDate: clock.date

  Accessible.ignored: true

  // Cut rather than faded, as the clock is: a shape from another surface had no pill showing,
  // a still is going, and the drop well had hidden all three.
  readonly property bool cut: root.origin !== null && (root.origin.handedOver || root.origin.held || !root.origin.fromClock)
  // Carried over from the open hover card, which has its clock up but none of the shut pill's marks.
  readonly property bool fromCard: root.origin !== null && root.origin.fromCard

  // Centred, as the bar pill's clock is: the marks are balanced either side of it.
  IslandClock {
    id: clock

    anchors.fill: parent
    origin: root.origin
    shown: root.shown
    progressDriven: root.progressDriven
    amount: root.amount
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
    visible: leftExtent + rightExtent > 0 && opacity > 0 && !root.fromCard
    opacity: root.progressDriven && !root.cut ? root.amount : root.shown ? 1 : 0

    Behavior on opacity {
      enabled: !root.cut && !root.progressDriven

      ContentFade {}
    }
  }
}
