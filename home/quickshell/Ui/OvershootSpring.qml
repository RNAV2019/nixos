import QtQuick
import qs.Commons

// Ui/MorphSpring.qml with a damping ratio below one, so the value runs a little past its target
// and settles back: the phone satellite's bud and retreat. Solved exactly for each frame's own
// time step, like the morph spring, so it lands on the same curve at any frame rate.
//
// Bind `target`, read `value`. A new target keeps the velocity.
QtObject {
  id: spring

  property real target: 0
  property real value: target
  property real velocity: 0

  property real omega: Theme.phoneSpringOmega
  // Below 1; at 1 or more use MorphSpring.
  property real damping: Theme.phoneSpringDamping

  property real epsilon: 0.001

  readonly property bool running: driver.running

  property bool ready: false

  Component.onCompleted: {
    value = target;
    ready = true;
  }

  onTargetChanged: {
    if (!ready || Theme.reduceMotion) {
      driver.stop();
      velocity = 0;
      value = target;
      return;
    }
    if (value !== target)
      driver.start();
  }

  // x'' = -2 z w x' - w^2 x, from (x, v), over dt.
  function step(dt) {
    var x = value - target;
    var v = velocity;
    if (Math.abs(x) < epsilon && Math.abs(v) < epsilon * 10) {
      driver.stop();
      velocity = 0;
      value = target;
      return;
    }
    var w = omega;
    var z = damping;
    var wd = w * Math.sqrt(1 - z * z);
    var e = Math.exp(-z * w * dt);
    var c = Math.cos(wd * dt);
    var s = Math.sin(wd * dt);
    value = target + e * (x * c + (v + z * w * x) / wd * s);
    velocity = e * (v * c - (z * w * v + w * w * x) / wd * s);
  }

  property FrameAnimation driver: FrameAnimation {
    running: false
    onTriggered: spring.step(Math.min(0.05, Math.max(0, frameTime)))
  }
}
