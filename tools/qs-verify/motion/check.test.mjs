import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { checkText } from "./check.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const line = (l, t, v, vel, tg) => `motion ${l} ${t} ${v} ${vel} ${tg}`;
const log = (rows) => rows.map((r) => line(...r)).join("\n");

// critically damped spring from 0 to 100, omega 21, sampled at 120 Hz
function clean(label = "island.w", n = 90, range = 100, dec = 4) {
  const w = 21, rows = [], A = range;
  for (let i = 0; i < n; i++) {
    const t = i * (1000 / 120), s = t / 1000;
    const x = A - A * (1 + w * s) * Math.exp(-w * s);
    const v = A * w * w * s * Math.exp(-w * s);
    rows.push([label, t.toFixed(1), x.toFixed(dec), v.toFixed(3), A]);
  }
  return rows;
}

test("stepping: value repeats on alternate frames while running", () => {
  const rows = clean();
  for (let i = 3; i < 20; i += 2) rows[i][2] = rows[i - 1][2];
  const f = checkText(log(rows));
  assert.ok(f.some((x) => x.rule === "stepping" && x.label === "island.w"));
});

test("overshoot: crosses the target, except phone.*", () => {
  const rows = clean();
  rows[40][2] = "100.8000";
  assert.ok(checkText(log(rows)).some((x) => x.rule === "overshoot"));
  const ph = rows.map((r) => ["phone.x", ...r.slice(1)]);
  assert.ok(!checkText(log(ph)).some((x) => x.rule === "overshoot"));
});

test("stall: velocity 0 mid-travel for an expected label only", () => {
  const rows = clean();
  rows[20][3] = "0.000";
  const expect = [/^island\./];
  assert.ok(checkText(log(rows), { expect }).some((x) => x.rule === "stall" && x.frame === 20));
  assert.ok(!checkText(log(rows)).some((x) => x.rule === "stall"));
});

test("clean critically damped trace: no failures, exit 0 from the CLI", () => {
  const rows = [...clean("island.w"), ...clean("control.h")];
  assert.deepEqual(checkText(log(rows), { expect: [/.*/] }), []);
  const d = mkdtempSync(join(tmpdir(), "check-"));
  writeFileSync(join(d, "a.log"), log(rows));
  const r = spawnSync("node", [join(here, "check.mjs"), d]);
  assert.equal(r.status, 0, r.stdout.toString());
  writeFileSync(join(d, "b.log"), log(rows.map((x, i) => (i === 30 ? [x[0], x[1], "130", x[3], x[4]] : x))));
  const bad = spawnSync("node", [join(here, "check.mjs"), d]);
  assert.equal(bad.status, 1);
  assert.match(bad.stdout.toString(), /b\.log: island\.w: overshoot at frame/);
});

test("coarse precision: a long clean tail with repeated printed values is not stepping", () => {
  for (const [dec, range] of [[2, 100], [2, 1000], [3, 100], [3, 1000], [4, 1000]]) {
    const rows = clean("island.w", 150, range, dec);
    assert.deepEqual(checkText(log(rows)), [], `decimals ${dec}, range ${range}`);
    const d = mkdtempSync(join(tmpdir(), "check-"));
    writeFileSync(join(d, "a.log"), log(rows));
    assert.equal(spawnSync("node", [join(here, "check.mjs"), d]).status, 0);
  }
});

test("coarse precision still catches real stepping early in the travel", () => {
  const rows = clean("island.w", 150).map((r) => [r[0], r[1], Number(r[2]).toFixed(2), r[3], 100]);
  for (let i = 3; i < 15; i += 2) rows[i][2] = rows[i - 1][2];
  assert.ok(checkText(log(rows)).some((x) => x.rule === "stepping"));
});

test("static: a contentX that follows the card fails, one that stays put passes", () => {
  const still = Array.from({ length: 30 }, (_, i) => ["surface.osd.contentX", (i * 8.3).toFixed(1), "812.0000", "0.0000", "812.0000"]);
  const riding = still.map((r, i) => [r[0], r[1], (812 - i * 2).toFixed(4), "0.0000", (812 - i * 2).toFixed(4)]);
  const opts = { expectStatic: [/^surface\..*\.contentX$/] };
  assert.deepEqual(checkText(log(still), opts), []);
  assert.ok(checkText(log(riding), opts).some((x) => x.rule === "static"));
  assert.ok(!checkText(log(riding)).some((x) => x.rule === "static"), "only labels asked for");
  // a second open elsewhere (gap in time) is another run, not a move
  const two = [...still, ...still.map((r) => [r[0], String(Number(r[1]) + 5000), "640.0000", r[3], "640.0000"])];
  assert.deepEqual(checkText(log(two), opts), []);
});

test("fade-frames: a one-frame cut fails, a four-frame fade passes", () => {
  const row = (t, v) => ["surface.control.body", String(t), v.toFixed(4), "0.0000", "0.0000"];
  const opts = { expectFadeFrames: [{ re: /^surface\..*\.body$/, n: 3 }] };
  assert.ok(checkText(log([row(0, 1), row(8, 1), row(16, 0)]), opts).some((x) => x.rule === "fade-frames"));
  assert.deepEqual(checkText(log([row(0, 1), row(8, 0.7), row(16, 0.2), row(25, 0)]), opts), []);
  assert.ok(!checkText(log([row(0, 1), row(8, 0)])).some((x) => x.rule === "fade-frames"), "only labels asked for");
});

test("monotonic: a restart that jumps back fails, a carried fade and a re-toggle pass", () => {
  const row = (t, v, tg) => ["surface.control.body", String(t), v.toFixed(4), "0.0000", tg.toFixed(4)];
  const opts = { expectMonotonic: [/^surface\..*\.body$/] };
  // open to 0.6, intent flips to close, falls to 0, then a deliberate re-toggle opens again
  const carried = [row(0, 0, 1), row(8, 0.3, 1), row(16, 0.6, 1), row(25, 0.6, 0), row(33, 0.3, 0), row(41, 0, 0), row(50, 0.2, 1), row(58, 0.9, 1)];
  assert.deepEqual(checkText(log(carried), opts), []);
  // the close restarts from 1 (a Behavior's restart), then the open climbs and dips
  const jumped = [row(0, 0, 1), row(8, 0.6, 1), row(16, 0.6, 0), row(25, 1, 0), row(33, 0.5, 0)];
  assert.ok(checkText(log(jumped), opts).some((x) => x.rule === "monotonic"));
  // a restart at the flip itself: 0.3 falls to 0.1 then the close jumps back to 0.9
  const flipJump = [row(0, 0, 1), row(8, 0.3, 1), row(16, 0.9, 0), row(25, 0.5, 0)];
  assert.ok(checkText(log(flipJump), opts).some((x) => x.rule === "monotonic"));
  // the previous intent's last frame landing on the flip sample is tolerated
  assert.deepEqual(checkText(log([row(0, 0, 1), row(8, 0.8, 1), row(16, 0.92, 0), row(25, 0.4, 0)]), opts), []);
  const dipped = [row(0, 0, 1), row(8, 0.6, 1), row(16, 0.5, 1), row(25, 1, 1)];
  assert.ok(checkText(log(dipped), opts).some((x) => x.rule === "monotonic"));
  assert.ok(!checkText(log(dipped)).some((x) => x.rule === "monotonic"), "only labels asked for");
});

test("continuity: a taker that starts from rest after a fast surface fails, one that carries the speed passes", () => {
  // control.w leaves at 1500 px/s at t=100; calendar.w takes over 20 ms later
  const out = [["surface.control.w", "92", "300.0000", "1400.000", "520"], ["surface.control.w", "100", "312.0000", "1500.000", "520"]];
  const rest = [["surface.calendar.w", "120", "312.5000", "150.000", "520"], ["surface.calendar.w", "128", "313.0000", "300.000", "520"]];
  const carried = [["surface.calendar.w", "120", "315.0000", "1450.000", "520"], ["surface.calendar.w", "128", "327.0000", "1480.000", "520"]];
  const opts = { expectContinuity: [/^surface\..*\.w$/] };
  assert.ok(checkText(log([...out, ...rest]), opts).some((x) => x.rule === "continuity" && x.label === "surface.calendar.w"));
  assert.deepEqual(checkText(log([...out, ...carried]), opts), []);
  assert.ok(!checkText(log([...out, ...rest])).some((x) => x.rule === "continuity"), "only labels asked for");
  // an outgoing surface heading the other way, or too slow, or long gone, is no handover to judge
  const away = out.map((r) => [r[0], r[1], r[2], "-1500.000", r[4]]);
  assert.deepEqual(checkText(log([...away, ...rest]), opts), []);
  const slow = out.map((r) => [r[0], r[1], r[2], "100.000", r[4]]);
  assert.deepEqual(checkText(log([...slow, ...rest]), opts), []);
  const late = rest.map((r) => [r[0], String(Number(r[1]) + 400), r[2], r[3], r[4]]);
  assert.deepEqual(checkText(log([...out, ...late]), opts), []);
  // the clamp: a taker 3 px from its target cannot take 1500 px/s, 21 * 3 = 63 is the most
  const near = [["surface.calendar.w", "120", "517.0000", "70.000", "520"]];
  assert.deepEqual(checkText(log([...out, ...near]), opts), []);
});

test("continuity: a taker that starts from rest after a fast surface fails, one that carries the speed passes", () => {
  // control.w leaves at 1500 px/s at t=100; calendar.w takes over 20 ms later
  const out = [["surface.control.w", "92", "300.0000", "1400.000", "520"], ["surface.control.w", "100", "312.0000", "1500.000", "520"]];
  const rest = [["surface.calendar.w", "120", "312.5000", "150.000", "520"], ["surface.calendar.w", "128", "313.0000", "300.000", "520"]];
  const carried = [["surface.calendar.w", "120", "315.0000", "1450.000", "520"], ["surface.calendar.w", "128", "327.0000", "1480.000", "520"]];
  const opts = { expectContinuity: [/^surface\..*\.w$/] };
  assert.ok(checkText(log([...out, ...rest]), opts).some((x) => x.rule === "continuity" && x.label === "surface.calendar.w"));
  assert.deepEqual(checkText(log([...out, ...carried]), opts), []);
  assert.ok(!checkText(log([...out, ...rest])).some((x) => x.rule === "continuity"), "only labels asked for");
  // an outgoing surface heading the other way, or too slow, or long gone, is no handover to judge
  const away = out.map((r) => [r[0], r[1], r[2], "-1500.000", r[4]]);
  assert.deepEqual(checkText(log([...away, ...rest]), opts), []);
  const slow = out.map((r) => [r[0], r[1], r[2], "100.000", r[4]]);
  assert.deepEqual(checkText(log([...slow, ...rest]), opts), []);
  const late = rest.map((r) => [r[0], String(Number(r[1]) + 400), r[2], r[3], r[4]]);
  assert.deepEqual(checkText(log([...out, ...late]), opts), []);
  // the clamp: a taker 3 px from its target cannot take 1500 px/s, 21 * 3 = 63 is the most
  const near = [["surface.calendar.w", "120", "517.0000", "70.000", "520"]];
  assert.deepEqual(checkText(log([...out, ...near]), opts), []);
});
