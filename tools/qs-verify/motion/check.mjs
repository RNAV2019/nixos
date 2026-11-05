#!/usr/bin/env node
// check.mjs OUT_DIR [--expect FILE] [--max-anim-ms N]
//
// Checks the motion logs (OUT_DIR/*.log) written by record.sh. A line is
//   motion <label> <t_ms> <value> <velocity> <target>
// Samples of one label in one file are one spring, in time order. Exit 1 if any rule fails; each
// failure prints "<file>: <label>: <rule> at frame <n> (t=<ms>): <detail>".
//
// Rules live in the RULES table below (name, enabled(opts), check(series, opts) -> failures).
// A later rule is one more entry plus its option in parseArgs.
//   stepping   running spring (|velocity| > 0, not at target) whose value did not change between
//              two consecutive frames
//   overshoot  value past the target in the direction of travel (labels not prefixed "phone.")
//   stall      velocity 0 while the target still differs, for labels matched by --expect FILE
//              (one glob per line, # comments), except at a deliberate stop: the frame where the
//              target changes (a spring starts at rest) and the last frame of a log.
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
    series.get(m[1]).push({ t, value, velocity, target });
  }
  for (const s of series.values()) s.sort((a, b) => a.t - b.t);
  return series;
}

const globToRe = (g) =>
  new RegExp("^" + g.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".") + "$");

const tolFor = (range) => Math.max(1e-3, 1e-3 * Math.abs(range));
const VEL_EPS = 1e-3;

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
    check(s) {
      const bad = [];
      for (let i = 1; i < s.length; i++) {
        const a = s[i - 1], b = s[i];
        const dist = Math.abs(b.target - b.value);
        if (b.target === a.target && Math.abs(b.velocity) > VEL_EPS && dist > tolFor(dist) && b.value === a.value)
          bad.push({ frame: i, t: b.t, detail: `value ${b.value} unchanged with velocity ${b.velocity}` });
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
  const o = { expect: [], maxAnimMs: null, ...opts };
  const out = [];
  for (const [label, s] of parseLog(text)) out.push(...checkSeries(label, s, o));
  return out;
}

function parseArgs(argv) {
  const o = { dir: null, expect: [], maxAnimMs: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--expect") o.expect = readFileSync(argv[++i], "utf8").split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#")).map(globToRe);
    else if (argv[i] === "--max-anim-ms") o.maxAnimMs = Number(argv[++i]);
    else if (!o.dir) o.dir = argv[i];
    else throw new Error(`unexpected argument ${argv[i]}`);
  }
  if (!o.dir) throw new Error("usage: check.mjs OUT_DIR [--expect FILE] [--max-anim-ms N]");
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
