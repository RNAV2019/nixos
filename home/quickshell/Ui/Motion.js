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

// ---- the phone satellite: a drop of liquid on a neck ----
//
// The disc's centre sits `x` px along the edge it rides, from `startInset` inside the edge (0) to
// its dock (`P.dock`). The disc grows over the first `P.grow` of that travel (see satelliteRadius).
// Going out it is held back by the neck joining it to the pill, so it starts slowly, speeds up as
// the neck stretches, and when the gap passes `P.breakGap` the neck snaps: the tension goes, the
// two broken ends recoil as `stubs`, and the disc settles into its dock with a little give. Coming
// in, a pull that grows as the gap shrinks draws it to the pill; on contact the neck re-forms and
// the pill's end swells (`bulge`) and relaxes. satelliteStep() is the whole simulation, pure and
// deterministic: the same state, params and dt give the same state.
//
// P: travel, startInset, satR, grow (share of travel the radius grows over), dock, reach (how far
// past the dock the pull would take it if the neck did not break), omega/zeta (the dock spring),
// rampFrom/rampTime (the pull builds from rampFrom to 1 over rampTime s), tension (neck pull back,
// 1/s^2 per px of stretch), tensionLead (px before contact it starts), breakGap, neckK (the
// fillet ball's radius, px), neckOn (s, how fast a re-formed neck swells), pull0/pull1 (the
// return's attraction, px/s^2, plain and added at the gap's smallest), pullDrag (1/s), mergeOmega,
// stubOmega/stubZeta, stubKick (1/s, the stubs' first speed), bulgeKick (px/s, see satelliteKick), bulgeOmega/bulgeZeta,
// bulgeVRef (px/s that gives the full bulge), maxHold (s), restEps (px).

function sat01(v) {
  return v < 0 ? 0 : v > 1 ? 1 : v;
}

function satelliteRadius(x, P) {
  return P.satR * sat01(x / P.travel / P.grow);
}

// The clear distance between the edge and the disc's near side; negative while they overlap.
function satelliteGap(x, P) {
  return x - P.startInset - satelliteRadius(x, P);
}

// The state at rest at the end the target names (1 out and docked, 0 in).
function satelliteRest(out, P) {
  return {
    x: out ? P.dock : 0,
    v: 0,
    broken: out,
    joint: 0,
    t: 0,
    out: out,
    stubs: 0,
    stubV: 0,
    bulge: 0,
    bulgeV: 0,
    snaps: 0,
    merges: 0,
    neck: 0,
    rest: true
  };
}

// The fillet ball's radius for the neck at this state: full while joined, shrinking to nothing
// over the last fifth of the stretch so the pinch reads as the neck thinning to a thread. It
// is also faded out while the disc is still inside the cap (gap below -5 px): a fillet between
// a wide pill and a small disc is a sharp wedge, and a bud should come out round.
function satelliteNeck(s, P) {
  if (s.broken || s.joint <= 0)
    return 0;
  var gap = satelliteGap(s.x, P);
  var thin = sat01((P.breakGap - gap) / (0.2 * P.breakGap));
  var size = ramp(gap, -5, 0.5);
  return P.neckK * s.joint * thin * size;
}

function satelliteSub(s, P, out, h) {
  var gap = satelliteGap(s.x, P);
  if (s.out !== out) {
    s.out = out;
    s.t = 0;
  }
  s.t += h;
  // Contact re-forms the neck, from either side, and a disc coming home makes the pill swell.
  if (s.broken && gap <= 0) {
    s.broken = false;
    s.stubs = 0;
    s.stubV = 0;
    s.merges++;
    if (s.v < 0)
      s.bulgeV += P.bulgeKick * sat01(-s.v / P.bulgeVRef);
  }
  if (!s.broken)
    s.joint = Math.min(1, s.joint + h / P.neckOn);
  var a;
  if (out) {
    if (!s.broken) {
      var g = P.rampFrom + (1 - P.rampFrom) * ramp(s.t / P.rampTime, 0, 1);
      var stretch = Math.max(0, gap + P.tensionLead);
      a = g * P.omega * P.omega * (P.dock + P.reach - s.x) - 2 * P.zeta * P.omega * s.v - P.tension * stretch;
    } else {
      a = P.omega * P.omega * (P.dock - s.x) - 2 * P.zeta * P.omega * s.v;
    }
  } else if (s.broken) {
    var near = sat01(1 - gap / satelliteGap(P.dock, P));
    a = -(P.pull0 + P.pull1 * near * near) - P.pullDrag * s.v;
  } else {
    a = P.mergeOmega * P.mergeOmega * (0 - s.x) - 2 * P.mergeOmega * s.v;
  }
  s.v += a * h;
  s.x += s.v * h;
  if (!out && s.x < 0) {
    s.x = 0;
    s.v = 0;
  }
  // It also lets go when the pull cannot take it any further (the neck holds it dead still) or
  // has been held for maxHold, so a neck that out-pulls the pull cannot hang there for ever.
  var stuck = s.t > P.rampTime && Math.abs(s.v) < 4 && satelliteGap(s.x, P) > satelliteGap(P.dock, P);
  if (out && !s.broken && (satelliteGap(s.x, P) >= P.breakGap || stuck || s.t > P.maxHold)) {
    s.broken = true;
    s.joint = 0;
    s.snaps++;
    s.stubs = 1;
    s.stubV = -P.stubKick;
  }
  if (s.stubs > 0 || s.stubV !== 0) {
    var r = springStep(s.stubs, s.stubV, P.stubOmega, P.stubZeta, h);
    s.stubs = r.x;
    s.stubV = r.v;
    if (s.stubs < 0.01 && s.stubV < 0.05) {
      s.stubs = 0;
      s.stubV = 0;
    }
  }
  if (s.bulge !== 0 || s.bulgeV !== 0) {
    var b = springStep(s.bulge, s.bulgeV, P.bulgeOmega, P.bulgeZeta, h);
    s.bulge = b.x;
    s.bulgeV = b.v;
    if (Math.abs(s.bulge) < 0.001 && Math.abs(s.bulgeV) < 0.01) {
      s.bulge = 0;
      s.bulgeV = 0;
    }
  }
}

// One frame: `s` advanced by dt seconds toward `out` (true: docked, false: home). Solved in
// substeps of at most 1/240 s, so the curve is the same at 60 and 120 Hz. Returns a new state.
function satelliteStep(s, P, out, dt) {
  var n = Math.max(1, Math.ceil(dt * 240 - 1e-9));
  var h = dt / n;
  var c = {};
  for (var k in s)
    c[k] = s[k];
  for (var i = 0; i < n; i++)
    satelliteSub(c, P, out, h);
  var goal = out ? P.dock : 0;
  c.rest = c.stubs === 0 && c.bulge === 0 && c.bulgeV === 0 && Math.abs(c.x - goal) < P.restEps && Math.abs(c.v) < P.restEps * 10 && (!out || c.broken);
  if (c.rest) {
    c.x = goal;
    c.v = 0;
  }
  c.neck = satelliteNeck(c, P);
  return c;
}

// The speed that sends an underdamped spring (omega, zeta < 1) from rest at 0 out to a peak of
// `size` before it comes back: the peak of v0 e^(-z w t) sin(wd t) / wd, solved for v0.
function satelliteKick(size, omega, zeta) {
  var wd = omega * Math.sqrt(1 - zeta * zeta);
  var tp = Math.atan2(wd, zeta * omega) / wd;
  return size * wd / (Math.exp(-zeta * omega * tp) * Math.sin(wd * tp));
}

// Content morph helpers (Ui/MorphLayer.qml): a straight blend of two numbers, two rects
// ({x, y, w, h}) and two colours ({r, g, b, a}).
function lerp(a, b, t) {
  return a + (b - a) * t;
}

function lerpRect(a, b, t) {
  return {
    x: a.x + (b.x - a.x) * t,
    y: a.y + (b.y - a.y) * t,
    w: a.w + (b.w - a.w) * t,
    h: a.h + (b.h - a.h) * t
  };
}

// How far a rect's middle goes from `a` to `b`: a pill that widens where it stands goes nowhere.
function travel(a, b) {
  return Math.hypot(a.x + a.w / 2 - b.x - b.w / 2, a.y + a.h / 2 - b.y - b.h / 2);
}

// Blended premultiplied, so a faint white lift turning into a solid accent passes through a fainter
// accent rather than a grey.
function lerpColor(a, b, t) {
  var al = a.a + (b.a - a.a) * t;
  var mix = function (x, y) {
    var v = x * a.a + (y * b.a - x * a.a) * t;
    return al > 0.0001 ? v / al : y;
  };
  return {
    r: mix(a.r, b.r),
    g: mix(a.g, b.g),
    b: mix(a.b, b.b),
    a: al
  };
}
