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
