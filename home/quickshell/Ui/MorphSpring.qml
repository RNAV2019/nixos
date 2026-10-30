import QtQuick
import qs.Commons

// The island's shape spring: one critically damped spring, so it never overshoots, solved
// exactly for each frame's own time step.
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

  property real omega: Theme.morphOmega

  // Damping ratio. 1 is critical and is what every morph uses; only the pill's slide
  // beside a satellite sets it lower (Theme.satelliteSlideZeta), for its one small overshoot.
  property real zeta: 1

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
    var w = omega;
    if (zeta < 1) {
      // Underdamped, solved exactly too: x(t) = e^(-zw t) (x cos(wd t) + b sin(wd t)).
      var zw = zeta * w;
      var wd = w * Math.sqrt(1 - zeta * zeta);
      var b = (v + zw * x) / wd;
      var decay = Math.exp(-zw * dt);
      var c = Math.cos(wd * dt);
      var s = Math.sin(wd * dt);
      value = target + decay * (x * c + b * s);
      velocity = decay * ((b * wd - zw * x) * c - (zw * b + x * wd) * s);
      return;
    }
    var e = Math.exp(-w * dt);
    var k = v + w * x;
    velocity = (k - w * (x + k * dt)) * e;
    value = target + (x + k * dt) * e;
  }

  property FrameAnimation driver: FrameAnimation {
    running: false
    // A stalled frame is solved for its whole length rather than slowed down; past 50 ms it is
    // clamped, so a long stall does not land the shape at rest in one jump.
    onTriggered: spring.step(Math.min(0.05, Math.max(0, frameTime)))
  }
}
