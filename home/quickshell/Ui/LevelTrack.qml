import QtQuick
import qs.Commons

// The board's `Level track`: a rounded groove with a fill, 0..1. Sized by the caller (166 x 8 in
// the OSD, 91 x 8 beside a label); the fill follows `value`, or with `indeterminate` a segment a
// quarter of the track slides across it while the total is not known.
Rectangle {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "track"
  property string morphKey: ""
  property var morphSlot: undefined

  property real value: 0
  property bool indeterminate: false

  // False for a state with no level to show, such as a muted OSD.
  property bool showFill: true

  // The sweep only runs while its surface is up.
  property bool running: true

  // Held keys repeat every 40 ms, so the OSD passes Theme.morphFill.
  property int fillDuration: Theme.duration(Theme.morphProgress)

  property color fillColor: Theme.accentFill

  readonly property real fraction: Theme.clamp01(value)
  readonly property alias fill: fill

  implicitWidth: Theme.islandPillTrackWidth
  implicitHeight: Theme.islandPillTrackHeight
  radius: height / 2
  color: Theme.lift(Theme.liftTrack)
  clip: true

  Rectangle {
    id: fill

    width: root.indeterminate || !root.showFill ? 0 : root.width * root.fraction
    height: root.height
    radius: root.radius
    color: root.fillColor

    Behavior on width {
      enabled: !Theme.reduceMotion

      Morph {
        duration: root.fillDuration
      }
    }
  }

  Rectangle {
    id: sweep

    readonly property real span: root.width * Theme.levelTrackSweepShare

    visible: root.indeterminate && !Theme.reduceMotion
    width: span
    height: root.height
    radius: root.radius
    color: root.fillColor

    NumberAnimation on x {
      from: -sweep.span
      to: root.width
      duration: Theme.levelTrackSweep
      loops: Animation.Infinite
      running: sweep.visible && root.running
    }
  }
}
