#!/usr/bin/env node
// check.mjs OUT_DIR [--expect FILE] [--expect-static GLOB[,GLOB]] [--expect-monotonic GLOB[,GLOB]] [--max-anim-ms N] [--resolution Q]
//
// Checks the motion logs (OUT_DIR/*.log) written by record.sh. A line is
//   motion <label> <t_ms> <value> <velocity> <target>
// Samples of one label in one file are one spring, in time order. Exit 1 if any rule fails; each
// failure prints "<file>: <label>: <rule> at frame <n> (t=<ms>): <detail>".
//
// Rules live in the RULES table below (name, enabled(opts), check(series, opts) -> failures).
// A later rule is one more entry plus its option in parseArgs.
//   stepping   running spring whose value repeats between two consecutive frames although its velocity
//              implies movement clearly above the logged precision (--resolution Q overrides it)
//   overshoot  value past the target in the direction of travel (labels not prefixed "phone.")
//   stall      velocity 0 while the target still differs, for labels matched by --expect FILE
//              (one glob per line, # comments), except at a deliberate stop: the frame where the
//              target changes (a spring starts at rest) and the last frame of a log.
//   static     labels matched by --expect-static must not change within a run of samples (the logger
//              only prints them while the surface's springs run)
//   monotonic  labels matched by --expect-monotonic (an opacity whose target is its intent, 1 or 0): within a
//              run of samples sharing a target the value never reverses direction. A new target starts a new run.
//   anim-length (only with --max-anim-ms N) a segment that travels longer than N ms
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, basename } from "node:path";

export function parseLog(text) {
  const series = new Map();
  for (const line of text.split("\n")) {
    const m = line.match(/^motion (\S+) (\S+) (\S+) (\S+) (\S+)\s*$/);
    if (!m) continue;
    const [t, value, velocity, target] = m.slice(2).map(Number);
    if ([t, value, velocity, target].some(Number.isNaN)) continue;
    if (!series.has(m[1])) series.set(m[1], []);
    series.get(m[1]).push({ t, value, velocity, target, dec: (m[3].split(".")[1] ?? "").length });
  }
  for (const s of series.values()) s.sort((a, b) => a.t - b.t);
  return series;
}

const globToRe = (g) =>
  new RegExp("^" + g.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".") + "$");

const tolFor = (range) => Math.max(1e-3, 1e-3 * Math.abs(range));

// Segments: runs of samples that share a target.
function segments(s) {
  const out = [];
  let cur = null;
  s.forEach((f, i) => {
    if (!cur || f.target !== cur.target) {
      const startValue = i > 0 ? s[i - 1].value : f.value;
      cur = { target: f.target, start: i, startValue, end: i };
      out.push(cur);
    }
    cur.end = i;
  });
  return out;
}

export const RULES = [
  {
    name: "stepping",
    enabled: () => true,
    // A repeat only counts when the movement the velocity implies for that frame (|v| * dt) is
    // clearly more than the printed quantum: a converging tail at coarse precision repeats values
    // legitimately. The quantum is 10^-decimals of the value as logged, or --resolution.
    check(s, o) {
      const bad = [];
      for (let i = 1; i < s.length; i++) {
        const a = s[i - 1], b = s[i];
        if (b.target !== a.target || b.value !== a.value) continue;
        const quantum = o.resolution ?? Math.pow(10, -Math.max(a.dec, b.dec));
        const expected = Math.abs(b.velocity) * (b.t - a.t) / 1000;
        const dist = Math.abs(b.target - b.value);
        if (expected > 3 * quantum && dist > 3 * quantum)
          bad.push({ frame: i, t: b.t, detail: `value ${b.value} unchanged though velocity ${b.velocity} implies ${expected.toPrecision(3)} of movement` });
      }
      return bad;
    },
  },
  {
    name: "overshoot",
    enabled: (_o, label) => !label.startsWith("phone."),
    check(s) {
      const bad = [];
      for (const seg of segments(s)) {
        const range = seg.target - seg.startValue;
        if (range === 0) continue;
        const dir = Math.sign(range);
        for (let i = seg.start; i <= seg.end; i++) {
          const past = (s[i].value - seg.target) * dir;
          if (past > tolFor(range)) {
            bad.push({ frame: i, t: s[i].t, detail: `value ${s[i].value} is ${past.toFixed(4)} past target ${seg.target}` });
            break;
          }
        }
      }
      return bad;
    },
  },
  {
    name: "stall",
    enabled: (o, label) => o.expect.some((re) => re.test(label)),
    check(s) {
      const bad = [];
      for (let i = 1; i < s.length - 1; i++) {
        const f = s[i];
        const dist = Math.abs(f.target - f.value);
        if (f.target === s[i - 1].target && s[i + 1].target === f.target && f.velocity === 0 && dist > tolFor(dist))
          bad.push({ frame: i, t: f.t, detail: `velocity 0 with ${dist.toFixed(4)} left to ${f.target}` });
      }
      return bad;
    },
  },
  {
    name: "static",
    enabled: (o, label) => o.expectStatic.some((re) => re.test(label)),
    // A label that must not move while its surface's springs run (it is only logged then). One run is
    // samples less than 100 ms apart; a new run (another open) may sit elsewhere.
    check(s) {
      const bad = [];
      let first = 0;
      for (let i = 1; i <= s.length; i++) {
        if (i < s.length && s[i].t - s[i - 1].t < 100) continue;
        const run = s.slice(first, i);
        const lo = Math.min(...run.map((f) => f.value)), hi = Math.max(...run.map((f) => f.value));
        if (hi - lo > 0.01) bad.push({ frame: first, t: run[0].t, detail: `moved ${(hi - lo).toFixed(4)} (${lo} to ${hi}) while its surface was moving` });
        first = i;
      }
      return bad;
    },
  },
  {
    name: "monotonic",
    enabled: (o, label) => o.expectMonotonic.some((re) => re.test(label)),
    // Segments share a target (the intent, 1 or 0), so a deliberate re-toggle starts a new one. Inside one,
    // the value may rest but never turn back by more than the printed quantum.
    check(s) {
      const bad = [];
      for (const seg of segments(s)) {
        const dir = Math.sign(seg.target - s[seg.start].value);
        if (!dir) continue;
        const tol = Math.pow(10, -Math.max(s[seg.start].dec, 3)) * 1.5;
        // The segment's first sample may still carry the last frame of the previous intent (the
        // log is sampled once per frame, the intent flips between two), so the direction is read
        // from the second sample on.
        for (let i = seg.start + 1; i <= seg.end; i++) {
          const prev = s[i - 1].value;
          if ((s[i].value - prev) * dir < -tol) {
            bad.push({ frame: i, t: s[i].t, detail: `value ${prev} then ${s[i].value}, against its direction to ${seg.target}` });
            break;
          }
        }
      }
      return bad;
    },
  },
  {
    name: "anim-length",
    enabled: (o) => o.maxAnimMs != null,
    check(s, o) {
      const bad = [];
      for (const seg of segments(s)) {
        if (seg.target === seg.startValue) continue;
        let endT = null;
        for (let i = seg.start; i <= seg.end; i++)
          if (Math.abs(s[i].target - s[i].value) <= tolFor(seg.target - seg.startValue)) { endT = s[i].t; break; }
        const t0 = s[seg.start].t;
        const dur = (endT ?? s[seg.end].t) - t0;
        if (dur > o.maxAnimMs) bad.push({ frame: seg.start, t: t0, detail: `animation ran ${dur} ms (> ${o.maxAnimMs})` });
      }
      return bad;
    },
  },
];

export function checkSeries(label, s, opts) {
  const out = [];
  for (const r of RULES) if (r.enabled(opts, label)) for (const b of r.check(s, opts)) out.push({ rule: r.name, label, ...b });
  return out;
}

export function checkText(text, opts = {}) {
  const o = { expect: [], expectStatic: [], expectMonotonic: [], maxAnimMs: null, resolution: null, ...opts };
  const out = [];
  for (const [label, s] of parseLog(text)) out.push(...checkSeries(label, s, o));
  return out;
}

function parseArgs(argv) {
  const o = { dir: null, expect: [], expectStatic: [], expectMonotonic: [], maxAnimMs: null, resolution: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--expect") o.expect = readFileSync(argv[++i], "utf8").split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#")).map(globToRe);
    else if (argv[i] === "--expect-static") o.expectStatic = argv[++i].split(",").map(globToRe);
    else if (argv[i] === "--expect-monotonic") o.expectMonotonic = argv[++i].split(",").map(globToRe);
    else if (argv[i] === "--resolution") o.resolution = Number(argv[++i]);
    else if (argv[i] === "--max-anim-ms") o.maxAnimMs = Number(argv[++i]);
    else if (!o.dir) o.dir = argv[i];
    else throw new Error(`unexpected argument ${argv[i]}`);
  }
  if (!o.dir) throw new Error("usage: check.mjs OUT_DIR [--expect FILE] [--expect-static GLOB[,GLOB]] [--expect-monotonic GLOB[,GLOB]] [--max-anim-ms N] [--resolution Q]");
  return o;
}

function main() {
  const o = parseArgs(process.argv.slice(2));
  if (!existsSync(o.dir)) throw new Error(`${o.dir} does not exist`);
  const files = readdirSync(o.dir).filter((f) => f.endsWith(".log")).sort();
  let failures = 0, lines = 0;
  for (const f of files) {
    const text = readFileSync(join(o.dir, f), "utf8");
    lines += [...parseLog(text).values()].reduce((n, s) => n + s.length, 0);
    for (const b of checkText(text, o)) {
      failures++;
      console.log(`${basename(f)}: ${b.label}: ${b.rule} at frame ${b.frame} (t=${b.t}): ${b.detail}`);
    }
  }
  console.log(`check: ${files.length} logs, ${lines} samples, ${failures} failures`);
  process.exit(failures ? 1 : 0);
}

import { fileURLToPath } from "node:url";
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try { main(); } catch (e) { console.error(`check: ${e.message}`); process.exit(2); }
}
