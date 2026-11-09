// Unit tests for the content morph's matcher (home/quickshell/Ui/MorphScan.js), loaded the way the
// file ships: the .pragma line is stripped and the rest evaluated.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "../../../home/quickshell/Ui/MorphScan.js"), "utf8").replace(/^\.pragma.*$/m, "");
const M = new Function(`${src}; return { match, assignSlots };`)();

const anchor = (role, x, y, w, h, extra = {}) => ({
  role, key: "", slot: undefined, parent: null, depth: 0, drawable: true,
  rect: { x, y, w, h }, box: { x, y, w, h }, parts: [], ...extra,
});

test("the same key pairs wherever the two are", () => {
  const a = [anchor("header", 0, 0, 500, 70, { key: "header" })];
  const b = [anchor("header", 300, 400, 500, 70, { key: "header" })];
  const m = M.match(a, b);
  assert.equal(m.pairs.length, 1);
  assert.equal(m.pairs[0].tier, "same");
});

test("the same role and slot pairs only when alike and close", () => {
  const a = [anchor("choice", 0, 0, 104, 88), anchor("choice", 114, 0, 104, 88), anchor("choice", 700, 0, 104, 88)];
  const b = [anchor("choice", 0, 0, 112, 88), anchor("choice", 122, 0, 300, 88), anchor("choice", 0, 500, 104, 88)];
  M.assignSlots(a);
  M.assignSlots(b);
  const m = M.match(a, b);
  // slot 0 pairs; slot 1 is too wide (300 / 104 > 1.6); slot 2 is too far away.
  assert.deepEqual(m.pairs.map((p) => [p.a.slot, p.b.slot]), [[0, 0]]);
  assert.equal(m.outs.length, 2);
  assert.equal(m.ins.length, 2);
});

test("a declared slot outranks reading order", () => {
  const a = [anchor("carousel", 300, 0, 100, 60, { slot: -1 }), anchor("carousel", 410, 0, 100, 60, { slot: 0 })];
  const b = [anchor("carousel", 410, 0, 100, 60, { slot: 0 }), anchor("carousel", 520, 0, 100, 60, { slot: 1 })];
  M.assignSlots(a);
  M.assignSlots(b);
  const m = M.match(a, b);
  assert.deepEqual(m.pairs.map((p) => p.a.slot), [0]);
});

test("a child pairs only under its parent's partner", () => {
  const ha = anchor("header", 0, 0, 500, 70, { key: "header" });
  const hb = anchor("header", 0, 0, 500, 70, { key: "header" });
  const loose = anchor("row", 0, 100, 500, 40);
  const ca = anchor("header.button", 440, 20, 32, 32, { parent: ha, depth: 1 });
  const cb = anchor("header.button", 440, 20, 32, 32, { parent: hb, depth: 1 });
  const stray = anchor("header.button", 440, 20, 32, 32, { parent: loose, depth: 1 });
  M.assignSlots([ha, ca]);
  M.assignSlots([hb, cb, loose, stray]);
  const m = M.match([ha, ca], [hb, loose, stray, cb]);
  assert.ok(m.pairs.some((p) => p.a === ca && p.b === cb));
  assert.ok(!m.pairs.some((p) => p.b === stray));
});

test("what cannot be redrawn and the rest never pair", () => {
  const rest = anchor("_rest", 0, 0, 10, 10, { rest: true });
  const opaque = anchor("opaque", 0, 0, 50, 50, { drawable: false, slot: 0 });
  const m = M.match([rest, { ...opaque }], [{ ...rest }, { ...opaque }]);
  assert.equal(m.pairs.length, 0);
  // The incoming rest is drawn through the mask, not counted as an arrival.
  assert.equal(m.ins.length, 1);
});

test("arrivals are ranked top to bottom", () => {
  const b = [anchor("row", 0, 300, 500, 40), anchor("row", 0, 100, 500, 40), anchor("row", 0, 200, 500, 40)];
  M.assignSlots(b);
  const m = M.match([], b);
  assert.deepEqual(m.ins.map((x) => [x.rect.y, x.rank]), [[300, 2], [100, 0], [200, 1]]);
});

test("inside paired parents, children pair by the last part of their role", () => {
  const pa = anchor("pill", 700, 10, 280, 42, { key: "level.volume" });
  const pb = anchor("slider", 716, 300, 488, 40, { key: "level.volume" });
  const ta = anchor("pill.track", 760, 28, 150, 6, { parent: pa, depth: 1 });
  const tb = anchor("slider.track", 716, 300, 488, 40, { parent: pb, depth: 1 });
  M.assignSlots([pa, ta]);
  M.assignSlots([pb, tb]);
  const m = M.match([pa, ta], [pb, tb]);
  assert.ok(m.pairs.some((p) => p.a === ta && p.b === tb));
});

test("carousel tiles pair in order however far the rows sit apart", () => {
  const a = [anchor("carousel", 20, 80, 160, 90), anchor("carousel", 190, 85, 136, 80), anchor("carousel", 340, 85, 136, 80)];
  const b = [anchor("carousel", 130, 85, 136, 80), anchor("carousel", 280, 85, 136, 80), anchor("carousel", 430, 80, 160, 90)];
  M.assignSlots(a);
  M.assignSlots(b);
  const m = M.match(a, b);
  assert.equal(m.pairs.length, 3);
});

test("inside one surface, the same role and slot pair whatever their keys", () => {
  const a = [anchor("pill", 700, 10, 280, 42, { key: "level.volume" })];
  const b = [anchor("pill", 700, 10, 280, 42, { key: "level.brightness" })];
  M.assignSlots(a);
  M.assignSlots(b);
  assert.equal(M.match(a, b).pairs.length, 0);
  assert.equal(M.match(a, b, { inPlace: true }).pairs.length, 1);
});

test("a taller tile in a row keeps its place in reading order", () => {
  const b = [anchor("carousel", 130, 85, 136, 80), anchor("carousel", 280, 85, 136, 80), anchor("carousel", 430, 80, 160, 90)];
  M.assignSlots(b);
  assert.deepEqual(b.map((x) => x.slot), [0, 1, 2]);
});

test("of several keys, the pair that shares first keys wins", () => {
  const head = anchor("header", 0, 0, 500, 70, { key: "header" });
  const label = anchor("device.name", 100, 200, 90, 20, { key: "device.Pixel" });
  const phone = anchor("header", 20, 20, 300, 24, { key: "device.Pixel|header" });
  const m = M.match([head, label], [phone]);
  assert.equal(m.pairs.length, 1);
  assert.equal(m.pairs[0].a, label);
  const back = M.match([phone], [head]);
  assert.equal(back.pairs.length, 1);
});

test("a rectangle's default border is no border", () => {
  const B = new Function(`${src}; return borderWidthOf;`)();
  const rect = (width, color) => ({ border: { width, color } });
  assert.equal(B(rect(1, { r: 0, g: 0, b: 0, a: 1 })), 0);
  assert.equal(B(rect(2, { r: 1, g: 1, b: 1, a: 0 })), 0);
  assert.equal(B(rect(1, { r: 0.2, g: 0.9, b: 0.7, a: 1 })), 1);
  assert.equal(B(rect(2, { r: 0, g: 0, b: 0, a: 1 })), 2);
});
