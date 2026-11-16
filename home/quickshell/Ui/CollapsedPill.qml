import QtQuick
import qs.Commons
import qs.Lyrics
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
  property var origin: null
  // Down while the owner draws nothing at all (a parked window): the words of a song are worked
  // out every frame, and are not for a pill nobody can see.
  property bool live: true

  // The pill is a song's just now (a line of lyrics, the dots, the title), not the clock's.
  // Opening, by what the island was showing when it was taken; closing, by what it will be
  // showing when it is uncovered, unless the way back is to the open card.
  readonly property bool faced: root.progressDriven ? Lyrics.faced && !root.fromCard : root.origin !== null ? root.origin.fromFace : Lyrics.faced

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
    shown: root.shown && !root.faced
    progressDriven: root.progressDriven
    amount: root.faced ? 0 : root.amount
  }

  // The song in the clock's place, as the bar's island draws it, coming and going as the marks do.
  Loader {
    y: (parent.height - height) / 2
    width: parent.width
    height: Theme.barHeight
    active: root.faced && root.live

    sourceComponent: LyricFace {
      // A surface is never narrower than the words it carries, and does not crop this to its shape.
      shaded: false
      presence: root.progressDriven && !root.faceCut ? root.amount : root.shown ? 1 : 0

      Behavior on presence {
        enabled: !root.faceCut && !root.progressDriven

        ContentFade {}
      }
    }
  }

  // The words fade where the clock would be cut: a shape taken from the island had them up.
  readonly property bool faceCut: root.origin !== null && (root.origin.handedOver || root.origin.held)
  readonly property real faceSide: Theme.islandLyricSide(root.recording, root.camera, root.microphone)

  PillMarks {
    anchors.fill: parent
    // Under a song the equaliser goes with the clock and the marks that stay hang off the room
    // kept either side of the words (Bar/Island.qml).
    equaliserEdge: parent.width / 2 - clock.clockWidth / 2
    clockLeft: root.faced ? root.faceSide : parent.width / 2 - clock.clockWidth / 2
    clockRight: root.faced ? parent.width - root.faceSide : parent.width / 2 + clock.clockWidth / 2
    mediaActive: root.mediaActive && !root.faced
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
