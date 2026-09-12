import QtQuick
import qs.Bar.Widgets
import qs.Commons
import qs.Services

// The one collapsed renderer used by transient surfaces and handoff stills. Keeping the clock,
// equaliser and recording mark together prevents a transient surface from handing back a subtly
// different pill than the bar owns.
Item {
  id: root

  property bool mediaActive: Media.active
  property bool playing: Media.playing
  property bool recording: Recorder.recording
  property bool shown: true
  property real clockShift: 0
  property var origin: null

  Accessible.ignored: true

  readonly property real collapsedGap: 7.5
  readonly property real resolvedClockShift: root.clockShift !== 0 ? root.clockShift : mediaActive ? (equaliser.implicitWidth + collapsedGap) / 2 : 0

  IslandClock {
    id: clock

    anchors.fill: parent
    origin: root.origin
    shown: root.shown
    clockShift: root.resolvedClockShift
  }

  Equaliser {
    id: equaliser

    x: parent.width / 2 + root.resolvedClockShift - Theme.islandClockSize * 1.5 - root.collapsedGap - implicitWidth
    y: (parent.height - implicitHeight) / 2
    playing: root.playing
    visible: root.mediaActive && opacity > 0
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
      Morph { duration: Theme.morphContent }
    }
  }

  Rectangle {
    x: parent.width / 2 + root.resolvedClockShift + clock.clockWidth / 2 + Theme.recorderDotGap
    y: (parent.height - height) / 2
    width: Theme.recorderDotSize
    height: width
    radius: width / 2
    color: Theme.urgent
    visible: root.recording && opacity > 0
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
      Morph { duration: Theme.morphContent }
    }
  }
}
