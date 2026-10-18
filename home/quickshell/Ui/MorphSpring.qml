import QtQuick
import qs.Commons

// The island's shape spring: one damped spring, solved exactly for each frame's own time step.
// SpringAnimation steps in fixed 16 ms quanta, so on a 120 Hz output a morph only moved on
// every other frame; this moves on every one, and lands on the same curve at any frame rate.
//
// Bind `target`, read `value`. A new target keeps the velocity, as a spring should. With
// `animate` down a new target is taken at once and any motion stops, which is what writing
// through a disabled Behavior does, so the `snapping` idiom in Ui/IslandOrigin.qml carries over.
QtObject {
  id: spring

  property real target: 0
  // Starts on the target, so nothing reads a shape in motion before the first change.
  property real value: target
  property real velocity: 0
  property bool animate: true

  property real zeta: Theme.morphZeta
  property real omega: Theme.morphOmega

  // At rest once within a tenth of a pixel and all but still.
  property real epsilon: 0.1

  readonly property bool running: driver.running

  property bool ready: false

  Component.onCompleted: {
    value = target;
    ready = true;
  }

  onTargetChanged: {
    if (!ready || !animate || Theme.reduceMotion) {
      driver.stop();
      velocity = 0;
      value = target;
      return;
    }
    if (value !== target)
      driver.start();
  }

  function step(dt) {
    // The gate and the target often turn on one change (a still letting go drops `held`, which
    // both read), in either order; a target taken while the gate was still up must not keep
    // travelling once it is down. Checked per frame rather than on the gate's change, since
    // `snapping` lowers and raises the gate inside one assignment, between frames.
    if (!animate) {
      driver.stop();
      velocity = 0;
      value = target;
      return;
    }
    var x = value - target;
    var v = velocity;
    if (Math.abs(x) < epsilon && Math.abs(v) < epsilon * 10) {
      driver.stop();
      velocity = 0;
      value = target;
      return;
    }
    var z = zeta;
    var w = omega;
    var nx;
    var nv;
    if (z < 1) {
      var wd = w * Math.sqrt(1 - z * z);
      var e = Math.exp(-z * w * dt);
      var c = Math.cos(wd * dt);
      var s = Math.sin(wd * dt);
      var b = (v + z * w * x) / wd;
      nx = e * (x * c + b * s);
      nv = e * ((b * wd - z * w * x) * c - (x * wd + z * w * b) * s);
    } else {
      // Critically damped (and the overdamped case, treated as critical).
      var ec = Math.exp(-w * dt);
      var k = v + w * x;
      nx = (x + k * dt) * ec;
      nv = (k - w * (x + k * dt)) * ec;
    }
    velocity = nv;
    value = target + nx;
  }

  property FrameAnimation driver: FrameAnimation {
    running: false
    // A stalled frame is solved for its whole length rather than slowed down; past 50 ms it is
    // clamped, so a long stall does not land the shape at rest in one jump.
    onTriggered: spring.step(Math.min(0.05, Math.max(0, frameTime)))
  }
}
