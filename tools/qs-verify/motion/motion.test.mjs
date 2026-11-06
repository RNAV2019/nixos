// Unit tests for home/quickshell/Ui/Motion.js, loaded the way the file ships: the .pragma line is
// stripped and the rest evaluated.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "../../../home/quickshell/Ui/Motion.js"), "utf8").replace(/^\.pragma.*$/m, "");
const M = new Function(`${src}; return { springStep, seedVelocity, progress, ramp, snap, satelliteStep, satelliteRest, satelliteGap, satelliteKick };`)();

// The formula MorphSpring.step inlined before Motion.js (critically damped branch, then ringing).
function oldStep(x, v, w, z, dt) {
  if (z < 1) {
    const wd = w * Math.sqrt(1 - z * z), ed = Math.exp(-z * w * dt);
    const c = Math.cos(wd * dt), s = Math.sin(wd * dt);
    return { x: ed * (x * c + (v + z * w * x) / wd * s), v: ed * (v * c - (z * w * v + w * w * x) / wd * s) };
  }
  const e = Math.exp(-w * dt), k = v + w * x;
  return { x: (x + k * dt) * e, v: (k - w * (x + k * dt)) * e };
}

function run(x, v, w, z, dt, ms) {
  let s = { x, v };
  for (let t = 0; t < ms - 1e-9; t += dt * 1000) s = M.springStep(s.x, s.v, w, z, dt);
  return s;
}

test("springStep matches the old MorphSpring formula", () => {
  // Numbers from running the old inlined formula once, from (10, 0) with omega 21 over 1/120 s.
  const a = M.springStep(10, 0, 21, 1, 1 / 120);
  assert.equal(a.x, 9.863619994038187);
  assert.equal(a.v, -30.85004551326837);
  const r = M.springStep(10, 0, 21, 0.7, 1 / 120);
  assert.equal(r.x, 9.85900468664797);
  assert.equal(r.v, -32.428372824780446);
  for (const [x, v, z, dt] of [[7, 40, 1, 0.016], [-3, 12, 1, 0.05], [5, -9, 0.7, 0.008]]) {
    assert.deepEqual(M.springStep(x, v, 21, z, dt), oldStep(x, v, 21, z, dt));
  }
});

test("120 Hz and 60 Hz stepping agree", () => {
  for (const z of [1, 0.7]) {
    const a = run(10, 0, 21, z, 1 / 120, 300);
    const b = run(10, 0, 21, z, 1 / 60, 300);
    assert.ok(Math.abs(a.x - b.x) < 0.01, `zeta ${z}: ${a.x} vs ${b.x}`);
  }
});

test("critically damped from rest never changes sign", () => {
  let s = { x: 10, v: 0 };
  for (let i = 0; i < 240; i++) {
    s = M.springStep(s.x, s.v, 21, 1, 1 / 120);
    assert.ok(s.x > 0, `crossed at step ${i}: ${s.x}`);
  }
});

test("seedVelocity", () => {
  assert.equal(M.seedVelocity(0, 100, -50, 21), 0);
  assert.equal(M.seedVelocity(0, 100, 5000, 21), 2100);
  assert.equal(M.seedVelocity(0, 100, 300, 21), 300);
  assert.equal(M.seedVelocity(0, -100, -5000, 21), -2100);
});

test("a seeded spring never overshoots", () => {
  let seed = 12345;
  const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  for (let n = 0; n < 500; n++) {
    const from = (rnd() - 0.5) * 400, target = (rnd() - 0.5) * 400;
    if (Math.abs(target - from) < 1) continue;
    const v = (rnd() - 0.5) * 20000, w = 10 + rnd() * 30;
    const dir = Math.sign(target - from);
    let s = { x: from - target, v: M.seedVelocity(from, target, v, w) };
    for (let i = 0; i < 480; i++) {
      s = M.springStep(s.x, s.v, w, 1, 1 / 120);
      assert.ok(s.x * dir <= 1e-9, `overshoot case ${n} step ${i}: x=${s.x}`);
    }
  }
});

test("progress", () => {
  assert.ok(Math.abs(M.progress(40, 42, 520, 400, 280, 42) - 0.5) < 1e-9);
  assert.ok(Number.isNaN(M.progress(520, 400, 520, 400, 520, 400)));
  assert.equal(M.progress(0, 0, 100, 10, 200, 0), 1);
  assert.equal(M.progress(0, 0, 0.2, 100, 0, 25), 0.25);
});

test("ramp", () => {
  assert.equal(M.ramp(0.5, 0, 1), 0.5);
  assert.equal(M.ramp(-1, 0, 1), 0);
  assert.equal(M.ramp(2, 0, 1), 1);
});

test("snap lands on the device-pixel grid", () => {
  const r = 1.3333334, v = M.snap(10.67, r);
  assert.ok(Math.abs(v / 0.75 - Math.round(v / 0.75)) < 1e-6, String(v));
});

// ---- the phone satellite's simulation (Theme.qml's phone tokens, 36 px bar) ----

const SAT = (() => {
  const satR = 18, startInset = 6, travel = startInset + 8 + satR;
  const P = {
    travel, startInset, satR, grow: 0.7, dock: travel, reach: 8, omega: 17, zeta: 0.7,
    rampFrom: 0.15, rampTime: 0.14, tension: 148, tensionLead: 10, breakGap: 9.5, maxHold: 0.6,
    neckK: 5.1, neckOn: 0.05, pull0: 500, pull1: 7000, pullDrag: 6, mergeOmega: 22,
    stubOmega: 30, stubZeta: 0.55, stubKick: 25, bulgeOmega: 30, bulgeZeta: 0.45, bulgeVRef: 200, restEps: 0.05,
  };
  P.bulgeKick = M.satelliteKick(2.5, P.bulgeOmega, P.bulgeZeta);
  return P;
})();

function satRun(out, dt, ms, from) {
  let s = from || M.satelliteRest(!out, SAT);
  const trace = [];
  for (let t = 0; t < ms - 1e-9; t += dt * 1000) {
    s = M.satelliteStep(s, SAT, out, dt);
    trace.push({ t: t + dt * 1000, s });
    if (s.rest) break;
  }
  return { s, trace };
}

test("satellite out: reaches the dock, breaks once, no NaN, gives by a few px at most", () => {
  const { s, trace } = satRun(true, 1 / 120, 3000);
  assert.ok(s.rest);
  assert.equal(s.x, SAT.dock);
  assert.equal(s.snaps, 1);
  assert.equal(s.merges, 0);
  for (const { s: q } of trace) for (const k of ["x", "v", "neck", "stubs", "bulge"]) assert.ok(Number.isFinite(q[k]), k);
  const over = Math.max(...trace.map((q) => q.s.x)) - SAT.dock;
  assert.ok(over > 0 && over <= 1.5, `give ${over}`);
  assert.ok(trace.every((q) => q.s.x > -0.001));
});

test("satellite out: starts slower than a plain spring, and the neck thins to nothing at the break", () => {
  const { trace } = satRun(true, 1 / 120, 60);
  const plain = M.springStep(-SAT.dock, 0, SAT.omega, SAT.zeta, 0.06);
  assert.ok(trace.at(-1).s.x < (plain.x + SAT.dock) / 2, `${trace.at(-1).s.x} vs ${plain.x + SAT.dock}`);
  const all = satRun(true, 1 / 120, 3000).trace;
  const iBreak = all.findIndex((q) => q.s.broken);
  assert.ok(iBreak > 0);
  assert.equal(all[iBreak].s.neck, 0);
  assert.ok(all[iBreak - 1].s.neck < all[iBreak - 4].s.neck, "thinning before it snaps");
  // The stubs start full at the snap, recoil, and are gone within 250 ms.
  assert.equal(all[iBreak].s.stubs > 0.5, true);
  const gone = all.findIndex((q, i) => i > iBreak && q.s.stubs === 0);
  assert.ok((gone - iBreak) / 120 < 0.25, `stubs ${(gone - iBreak) / 120}`);
});

test("satellite in: merges once, the pill swells and relaxes, ends home", () => {
  const { s, trace } = satRun(false, 1 / 120, 3000);
  assert.ok(s.rest);
  assert.equal(s.x, 0);
  assert.equal(s.merges, 1);
  assert.equal(s.snaps, 0);
  assert.equal(s.bulge, 0);
  const peak = Math.max(...trace.map((q) => q.s.bulge));
  assert.ok(peak > 1.5 && peak < 3, `bulge ${peak}`);
  // Pulled in: it speeds up on the way to contact.
  const vs = trace.filter((q) => q.s.broken).map((q) => Math.abs(q.s.v));
  assert.ok(vs.at(-1) > vs[Math.floor(vs.length / 2)]);
});

test("satellite: 120 Hz and 60 Hz are the same curve", () => {
  for (const out of [true, false]) {
    const a = satRun(out, 1 / 120, 1000).trace;
    const b = satRun(out, 1 / 60, 1000).trace;
    for (const q of b) {
      const m = a.find((r) => Math.abs(r.t - q.t) < 0.01);
      if (m) assert.ok(Math.abs(m.s.x - q.s.x) < 0.1, `${out} ${q.t}: ${m.s.x} ${q.s.x}`);
    }
  }
});

test("satellite: turning round mid-flight neither breaks twice nor sticks", () => {
  let s = satRun(true, 1 / 120, 120).s;
  s = satRun(false, 1 / 120, 3000, s).s;
  assert.ok(s.rest && s.x === 0);
  let u = satRun(false, 1 / 120, 3000).s;
  u = satRun(true, 1 / 120, 120, u).s;
  u = satRun(true, 1 / 120, 3000, u).s;
  assert.ok(u.rest && u.x === SAT.dock);
  assert.equal(u.snaps, 1);
});

test("satellite: the rest state is at rest and carries no neck", () => {
  for (const out of [true, false]) {
    const r = M.satelliteRest(out, SAT);
    const n = M.satelliteStep(r, SAT, out, 1 / 120);
    assert.ok(n.rest && n.neck === 0 && n.stubs === 0 && n.bulge === 0);
    assert.equal(n.x, out ? SAT.dock : 0);
  }
});

test("satellite: the first snap comes before 400 ms at 60, 120 and 144 Hz and across a stalled frame", () => {
  const snapAt = (dts) => {
    let s = M.satelliteRest(false, SAT), t = 0;
    for (let i = 0; i < 2000 && s.snaps === 0; i++) {
      const dt = dts(i);
      s = M.satelliteStep(s, SAT, true, dt);
      t += dt * 1000;
    }
    return s.snaps === 1 ? t : Infinity;
  };
  for (const hz of [60, 120, 144]) assert.ok(snapAt(() => 1 / hz) < 400, `${hz} Hz: ${snapAt(() => 1 / hz)}`);
  // A 50 ms frame (the clamp) in the middle of the stretch.
  const stalled = snapAt((i) => (i === 15 ? 0.05 : 1 / 120));
  assert.ok(stalled < 400, `stalled frame: ${stalled}`);
});

test("satellite: the rest states carry no neck, stubs or swell (the reduce-motion snap)", () => {
  for (const out of [true, false]) {
    const r = M.satelliteRest(out, SAT);
    assert.equal(r.neck, 0);
    assert.equal(r.stubs, 0);
    assert.equal(r.stubV, 0);
    assert.equal(r.bulge, 0);
    assert.equal(r.bulgeV, 0);
    assert.equal(r.v, 0);
    assert.equal(r.x, out ? SAT.dock : 0);
  }
});
