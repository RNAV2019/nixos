// Unit tests for home/quickshell/Ui/Motion.js, loaded the way the file ships: the .pragma line is
// stripped and the rest evaluated.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "../../../home/quickshell/Ui/Motion.js"), "utf8").replace(/^\.pragma.*$/m, "");
const M = new Function(`${src}; return { springStep, seedVelocity, progress, ramp, snap };`)();

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
