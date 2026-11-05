import QtQuick
import qs.Commons
import "Motion.js" as Motion

// The island's shape spring: one critically damped spring, so it never overshoots, solved
// exactly for each frame's own time step.
// It steps with every frame's own time, so on a 120 Hz output it moves on every frame, and it lands
// on the same curve at any frame rate.
//
// Bind `target`, read `value`. A new target keeps the velocity, as a spring should. With
// `animate` down a new target is taken at once and any motion stops, which is what writing
// through a disabled Behavior does, so the `snapping` idiom in Ui/IslandOrigin.qml carries over.
//
// A `damping` ratio below one makes it underdamped: the value runs a little past its target and
// settles back. Only the phone satellite asks for that; the shell's surfaces have no overshoot.
//
// With QS_MOTION_LOG=1 (Theme.motionLog) and a `label`, every frame prints
// `motion <label> <t_ms> <value> <velocity> <target>` for tools/qs-verify/motion/check.mjs.
// One label is one spring, so a spring per Repeater item needs an index in its label.
QtObject {
  id: spring

  property real target: 0
  // Starts on the target, so nothing reads a shape in motion before the first change.
  property real value: target
  property real velocity: 0
  property bool animate: true

  property real omega: Theme.morphOmega
  // 1 is critically damped; below 1 overshoots, by about 4.6% of the travel at 0.7.
  property real damping: 1

  // At rest once within a tenth of a pixel and all but still; a value that is not in pixels
  // sets its own.
  property real epsilon: 0.3

  // Names this spring in the motion log; empty keeps it out.
  property string label: ""

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

  // Sets the velocity (a handover from something that was already moving) and wakes the driver.
  function kick(v) {
    velocity = v;
    if (value !== target && ready && animate && !Theme.reduceMotion)
      driver.start();
  }

  function log() {
    // Guarded before the string is built: nothing is formatted when the log is off.
    if (Theme.motionLog && label !== "")
      console.info("motion " + label + " " + Date.now() + " " + value.toFixed(4) + " " + velocity.toFixed(4) + " " + target.toFixed(4));
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
      log();
      return;
    }
    var r = Motion.springStep(x, v, omega, damping, dt);
    value = target + r.x;
    velocity = r.v;
    log();
  }

  property FrameAnimation driver: FrameAnimation {
    running: false
    // A stalled frame is solved for its whole length rather than slowed down; past 50 ms it is
    // clamped, so a long stall does not land the shape at rest in one jump.
    onTriggered: spring.step(Math.min(0.05, Math.max(0, frameTime)))
  }
}
