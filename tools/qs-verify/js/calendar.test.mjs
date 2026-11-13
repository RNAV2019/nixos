// Unit tests for the calendar's day map (home/quickshell/Commons/CalendarDays.js), loaded the way
// the file ships: the .pragma line is stripped and the rest evaluated. The map replaces a scan of
// every event per grid cell, so the reference here is that scan, copied from Services/Calendar.qml
// as it was (sameDay on the start, then all-day first, then by start), and every case is the map
// agreeing with it, order included.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "../../../home/quickshell/Commons/CalendarDays.js"), "utf8").replace(/^\.pragma.*$/m, "");
const D = new Function(`${src}; return { build, on };`)();

function sameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function scanOn(events, day) {
  const out = [];
  for (let i = 0; i < events.length; i++) {
    if (sameDay(events[i].start, day)) out.push(events[i]);
  }
  out.sort((a, b) => {
    if (a.allDay !== b.allDay) return a.allDay ? -1 : 1;
    return a.start - b.start;
  });
  return out;
}

const at = (y, m, d, h = 0, min = 0) => new Date(y, m - 1, d, h, min);
let n = 0;
const timed = (start, end, extra = {}) => ({ start, end, allDay: false, title: "e" + n++, calendar: "c", location: "", ...extra });
const allDay = (start, end, extra = {}) => ({ start, end, allDay: true, title: "e" + n++, calendar: "c", location: "", ...extra });

// Every day in [from, to] as the grid would ask for it.
function days(from, to) {
  const out = [];
  for (let d = new Date(from); d <= to; d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)) out.push(d);
  return out;
}

function agree(events, from, to) {
  const map = D.build(events);
  for (const day of days(from, to)) {
    const got = D.on(map, day);
    const want = scanOn(events, day);
    assert.equal(got.length, want.length, `${day.toDateString()}: count`);
    for (let i = 0; i < want.length; i++) assert.equal(got[i], want[i], `${day.toDateString()}: row ${i}`);
  }
  return map;
}

test("a day with no events is empty, and a day is never another day's", () => {
  const map = agree([timed(at(2026, 11, 13, 9), at(2026, 11, 13, 10))], at(2026, 11, 1), at(2026, 11, 30));
  assert.deepEqual(D.on(map, at(2026, 11, 12)), []);
  assert.equal(D.on(map, at(2026, 11, 13, 23, 59)).length, 1);
});

test("all-day events come first, then timed ones by start, whatever order they arrived in", () => {
  const events = [
    timed(at(2026, 11, 13, 15), at(2026, 11, 13, 16), { title: "late" }),
    allDay(at(2026, 11, 13), at(2026, 11, 14), { title: "all day b" }),
    timed(at(2026, 11, 13, 8), at(2026, 11, 13, 9), { title: "early" }),
    allDay(at(2026, 11, 13), at(2026, 11, 14), { title: "all day a" }),
    timed(at(2026, 11, 13, 8), at(2026, 11, 13, 8, 30), { title: "early, arrived later" }),
  ];
  const map = agree(events, at(2026, 11, 13), at(2026, 11, 13));
  assert.deepEqual(D.on(map, at(2026, 11, 13)).map(e => e.title), ["all day b", "all day a", "early", "early, arrived later", "late"]);
});

test("an event shows on the day it starts, not the days it runs through", () => {
  const events = [
    allDay(at(2026, 11, 10), at(2026, 11, 14), { title: "trip" }),
    timed(at(2026, 11, 12, 22), at(2026, 11, 13, 2), { title: "overnight" }),
  ];
  const map = agree(events, at(2026, 11, 9), at(2026, 11, 15));
  assert.equal(D.on(map, at(2026, 11, 11)).length, 0);
  assert.equal(D.on(map, at(2026, 11, 13)).length, 0);
  assert.equal(D.on(map, at(2026, 11, 12))[0].title, "overnight");
});

test("a multi-day event across a month or year boundary stays on its start day", () => {
  const events = [
    allDay(at(2026, 10, 30), at(2026, 11, 3), { title: "autumn break" }),
    timed(at(2026, 12, 31, 23, 30), at(2027, 1, 1, 1), { title: "new year" }),
    allDay(at(2027, 1, 1), at(2027, 1, 2), { title: "holiday" }),
  ];
  const map = agree(events, at(2026, 10, 26), at(2027, 2, 7));
  assert.deepEqual(D.on(map, at(2026, 12, 31)).map(e => e.title), ["new year"]);
  assert.deepEqual(D.on(map, at(2027, 1, 1)).map(e => e.title), ["holiday"]);
  assert.equal(D.on(map, at(2026, 11, 1)).length, 0);
});

test("an event that ends exactly at midnight does not spill onto the next day", () => {
  const events = [timed(at(2026, 11, 13, 22), at(2026, 11, 14, 0), { title: "until midnight" })];
  const map = agree(events, at(2026, 11, 12), at(2026, 11, 15));
  assert.equal(D.on(map, at(2026, 11, 14)).length, 0);
  assert.equal(D.on(map, at(2026, 11, 13)).length, 1);
});

test("an event that starts exactly at midnight is that day's, and the minute before is the day before's", () => {
  const events = [timed(at(2026, 11, 14, 0, 0), at(2026, 11, 14, 1)), timed(at(2026, 11, 13, 23, 59), at(2026, 11, 14, 0, 30))];
  const map = agree(events, at(2026, 11, 12), at(2026, 11, 15));
  assert.equal(D.on(map, at(2026, 11, 14)).length, 1);
  assert.equal(D.on(map, at(2026, 11, 13)).length, 1);
});

// The map and the scan both read the local calendar day, so they must agree wherever the
// machine is, including on the days a clock change skips or repeats an hour.
for (const [zone, from, to] of [
  ["Europe/London", at(2026, 3, 27), at(2026, 3, 31)],
  ["Europe/London", at(2026, 10, 24), at(2026, 10, 28)],
  ["America/New_York", at(2026, 3, 7), at(2026, 3, 10)],
  ["America/New_York", at(2026, 10, 31), at(2026, 11, 3)],
  ["Pacific/Auckland", at(2026, 9, 25), at(2026, 9, 29)],
  ["Pacific/Kiritimati", at(2026, 11, 10), at(2026, 11, 16)],
  ["Pacific/Pago_Pago", at(2026, 11, 10), at(2026, 11, 16)],
]) {
  test(`time zone ${zone}, ${from.toDateString()} to ${to.toDateString()}`, () => {
    const was = process.env.TZ;
    process.env.TZ = zone;
    try {
      const events = [];
      for (const day of days(from, to)) {
        const y = day.getFullYear(), m = day.getMonth() + 1, d = day.getDate();
        events.push(timed(at(y, m, d, 0, 30), at(y, m, d, 1, 30)));
        events.push(timed(at(y, m, d, 1, 30), at(y, m, d, 2, 30)));
        events.push(timed(at(y, m, d, 23, 30), at(y, m, d + 1, 0, 30)));
        events.push(allDay(at(y, m, d), at(y, m, d + 1)));
      }
      agree(events, from, to);
    } finally {
      if (was === undefined) delete process.env.TZ;
      else process.env.TZ = was;
    }
  });
}

test("a month of generated events reads the same as the scan, day by day", () => {
  let seed = 7;
  const next = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
  const events = [];
  for (let i = 0; i < 400; i++) {
    const d = 1 + Math.floor(next() * 35);
    const start = at(2026, 10, d, Math.floor(next() * 24), Math.floor(next() * 4) * 15);
    const end = new Date(start.getTime() + Math.floor(next() * 40) * 3600000);
    events.push(next() < 0.2 ? allDay(new Date(start.getFullYear(), start.getMonth(), start.getDate()), end) : timed(start, end));
  }
  agree(events, at(2026, 9, 24), at(2026, 12, 8));
});

test("every call hands out an array of its own", () => {
  const events = [timed(at(2026, 11, 13, 9), at(2026, 11, 13, 10))];
  const map = D.build(events);
  assert.notEqual(D.on(map, at(2026, 11, 13)), D.on(map, at(2026, 11, 13, 18)));
  assert.deepEqual(D.on(map, at(2026, 11, 13)), D.on(map, at(2026, 11, 13, 18)));
  assert.notEqual(D.on(map, at(2026, 11, 12)), D.on(map, at(2026, 11, 12)));
});
