import QtQuick
import qs.Commons

// The board's `Spinner`: a quarter of a Ring turning over its faint track, 20 px by default,
// with 2 px strokes, as the login pill draws it. It only turns while it is on screen.
Ring {
  id: root

  property bool running: true
  // Off where something else already draws the ring it turns over.
  property bool track: true

  value: 0.25
  trackColor: root.track ? Theme.withAlpha(Theme.inkTertiary, 0.35) : "transparent"

  RotationAnimator on rotation {
    from: 0
    to: 360
    duration: Theme.lockSpinnerTurn
    loops: Animation.Infinite
    running: root.running && root.visible && !Theme.reduceMotion
  }
}
