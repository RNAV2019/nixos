.pragma library

// Motion maths shared by the shell's springs and by anything that wants to follow one.
// No QML imports: it loads as a plain library, and tools/qs-verify/motion/motion.test.mjs
// evaluates this file under node.

// One step of a spring over dt seconds, solved exactly (not integrated), so it lands on the same
// curve at any frame rate. `x` is the displacement from the target, `v` its velocity; returns the
// new {x, v}. zeta === 1 is critically damped (never crosses the target); below 1 it rings.
function springStep(x, v, omega, zeta, dt) {
  if (zeta < 1) {
    // x'' = -2 z w x' - w^2 x, from (x, v), over dt.
    var wd = omega * Math.sqrt(1 - zeta * zeta);
    var ed = Math.exp(-zeta * omega * dt);
    var c = Math.cos(wd * dt);
    var s = Math.sin(wd * dt);
    return {
      x: ed * (x * c + (v + zeta * omega * x) / wd * s),
      v: ed * (v * c - (zeta * omega * v + omega * omega * x) / wd * s)
    };
  }
  var e = Math.exp(-omega * dt);
  var k = v + omega * x;
  return {
    x: (x + k * dt) * e,
    v: (k - omega * (x + k * dt)) * e
  };
}

// The velocity to start a critically damped spring from when it takes over a motion that has
// velocity `v`: 0 when `v` heads away from `target`, else `v` clamped to omega * |target - from|,
// the fastest a critically damped spring can start without crossing its target.
function seedVelocity(from, target, v, omega) {
  var d = target - from;
  if (v * d <= 0)
    return 0;
  var limit = omega * Math.abs(d);
  return Math.abs(v) > limit ? (v < 0 ? -limit : limit) : v;
}

// How far a size has travelled from (fromW, fromH) to (toW, toH), measured along the axis that
// travels further, clamped to 0..1. NaN when neither axis moves more than half a pixel.
function progress(fromW, fromH, toW, toH, w, h) {
  var dw = toW - fromW;
  var dh = toH - fromH;
  var p;
  if (Math.abs(dw) >= Math.abs(dh) && Math.abs(dw) > 0.5)
    p = (w - fromW) / dw;
  else if (Math.abs(dh) > 0.5)
    p = (h - fromH) / dh;
  else
    return NaN;
  return Math.min(1, Math.max(0, p));
}

// A smoothstep of p over [start, end], clamped to 0..1.
function ramp(p, start, end) {
  var t = Math.min(1, Math.max(0, (p - start) / (end - start)));
  return t * t * (3 - 2 * t);
}

// v rounded to the device-pixel grid of a surface at `ratio`.
function snap(v, ratio) {
  return Math.round(v * ratio) / ratio;
}
