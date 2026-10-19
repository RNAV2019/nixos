import QtQuick
import qs.Bar.Widgets
import qs.Commons
import qs.Services

// The marks either side of the shut pill's clock. The clock stays centred and the pill only
// widens once the heavier side outgrows its padding, so the marks are split to keep the sides
// even: the equaliser and the camera to the left, the recording dot and the microphone right.
// A call reads camera | clock | microphone, music and a recording equaliser | clock | dot.
// Each grows in out of the space the pill opens for it and shrinks back out, and the marks
// beyond it slide to make room, so nothing teleports when one comes or goes. Fills the pill.
Item {
  id: root

  property bool mediaActive: Media.active
  property bool playing: Media.playing
  property bool recording: Recorder.recording
  property bool camera: Privacy.camera
  property bool microphone: Privacy.microphone

  // The clock's shown edges, in this item's coordinates; the marks hang off them.
  property real clockLeft: 0
  property real clockRight: 0

  // How far each side reaches past the clock, leading gaps included. Animated, on the pace
  // the pill's width springs at.
  readonly property real leftExtent: eq.room + cam.room
  readonly property real rightExtent: rec.room + mic.room

  // One mark. `presence` runs 0..1 and carries its room, opacity and scale, so the slide,
  // the fade and the growth are one motion.
  component Mark: Item {
    property bool active: false
    property real lead: 0
    property real size: 0
    property real presence: active ? 1 : 0
    readonly property real room: (lead + size) * presence

    Behavior on presence {
      Morph {}
    }

    y: (root.height - height) / 2
    width: size
    height: size
    visible: presence > 0
    opacity: presence
    scale: 0.4 + 0.6 * presence
  }

  Mark {
    id: eq

    active: root.mediaActive
    lead: Theme.islandMarkClockGap
    size: equaliser.implicitWidth
    height: equaliser.implicitHeight
    x: root.clockLeft - lead * presence - size

    Equaliser {
      id: equaliser

      playing: root.playing
    }
  }

  Mark {
    id: cam

    active: root.camera
    // Off the clock on its own, or the gap between marks beyond the equaliser, eased with it.
    lead: Theme.islandMarkClockGap - (Theme.islandMarkClockGap - Theme.islandMarkGap) * eq.presence
    size: Theme.privacyGlyphSize
    x: root.clockLeft - eq.room - lead * presence - size

    StrokeIcon {
      size: parent.size
      path: IconPaths.camera
      color: Theme.cameraMark
      strokeWidth: Theme.privacyGlyphStroke
    }
  }

  Mark {
    id: rec

    active: root.recording
    lead: Theme.islandMarkClockGap
    size: Theme.recorderDotSize
    x: root.clockRight + lead * presence

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Theme.urgent
    }
  }

  Mark {
    id: mic

    active: root.microphone
    lead: Theme.islandMarkClockGap - (Theme.islandMarkClockGap - Theme.islandMarkGap) * rec.presence
    size: Theme.privacyGlyphSize
    x: root.clockRight + rec.room + lead * presence

    StrokeIcon {
      size: parent.size
      path: IconPaths.microphone
      color: Theme.microphoneMark
      strokeWidth: Theme.privacyGlyphStroke
    }
  }
}
