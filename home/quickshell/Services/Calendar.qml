pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/CalendarDays.js" as CalendarDays

// Google Calendar via ical-agenda (see home/ical-agenda.nix): the secret iCal address
// is decrypted by sops-nix, so nothing here sees it. Events are cached by month.
Singleton {
  id: root

  // The month on screen, as the first of that month.
  property date anchor: {
    var now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  }

  // Which day the agenda below the grid is for.
  property date selected: new Date()

  // Today at midnight: the same value all day, and the next one from midnight on, so what
  // reads it (the grid's ring, "Today" over the agenda) moves on without the panel reopening.
  readonly property date todayDate: new Date(Math.floor(dayStamp / 10000), Math.floor(dayStamp / 100) % 100, dayStamp % 100)

  // The clock ticks each minute; a number that is the same all day keeps that from the readers.
  readonly property int dayStamp: clock.date.getFullYear() * 10000 + clock.date.getMonth() * 100 + clock.date.getDate()

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  property bool loading: false

  // Set when ical-agenda cannot answer, which on a fresh machine means no address yet.
  property string error: ""

  // month key -> array of events. An event is
  // { start: Date, end: Date, allDay: bool, title, calendar, location }.
  property var months: ({})
  property string pendingKey: ""
  property bool pendingForce: false

  readonly property string monthKey: root.keyFor(root.anchor)

  readonly property var events: root.months[root.monthKey] || []

  function keyFor(d) {
    return d.getFullYear() + "-" + (d.getMonth() + 1);
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  // The month's events by the day they start on, built once per fetch.
  readonly property var dayMap: CalendarDays.build(root.events)

  // The events on one day, in start order, all-day first.
  function eventsOn(day) {
    return CalendarDays.on(root.dayMap, day);
  }

  function hasEvents(day) {
    return CalendarDays.on(root.dayMap, day).length > 0;
  }

  // A stable colour per calendar, independent of which event arrived first.
  function colourFor(name) {
    return Theme.stableAccent(name);
  }

  function step(months) {
    var d = new Date(root.anchor.getFullYear(), root.anchor.getMonth() + months, 1);
    root.anchor = d;
    var day = Math.min(root.selected.getDate(), new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate());
    root.selected = new Date(d.getFullYear(), d.getMonth(), day);
    root.load();
  }

  function selectDay(day) {
    root.selected = new Date(day.getFullYear(), day.getMonth(), day.getDate());
    root.anchor = new Date(root.selected.getFullYear(), root.selected.getMonth(), 1);
    root.load();
  }

  function stepDay(days) {
    var next = new Date(root.selected.getFullYear(), root.selected.getMonth(), root.selected.getDate() + days);
    root.selected = next;
    if (next.getMonth() !== root.anchor.getMonth() || next.getFullYear() !== root.anchor.getFullYear()) {
      root.anchor = new Date(next.getFullYear(), next.getMonth(), 1);
      root.load();
    }
  }

  function today() {
    var now = new Date();
    root.anchor = new Date(now.getFullYear(), now.getMonth(), 1);
    root.selected = now;
    root.load();
  }

  function pad(n) {
    return (n < 10 ? "0" : "") + n;
  }

  function stamp(d) {
    return d.getFullYear() + "-" + root.pad(d.getMonth() + 1) + "-" + root.pad(d.getDate());
  }

  // The grid shows neighbouring months, so the fetch is padded a week either side.
  // `force` is the user asking again and goes down as --refresh to re-download feeds.
  function load(force) {
    if (root.months[root.monthKey] !== undefined)
      return;
    if (fetch.running) {
      root.pendingKey = root.monthKey;
      root.pendingForce = root.pendingForce || force === true;
      return;
    }
    var from = new Date(root.anchor.getFullYear(), root.anchor.getMonth(), 1 - 7);
    var to = new Date(root.anchor.getFullYear(), root.anchor.getMonth() + 1, 7);
    root.loading = true;
    fetch.key = root.monthKey;
    fetch.command = ["ical-agenda"].concat(force ? ["--refresh"] : []).concat([root.stamp(from), root.stamp(to)]);
    fetch.running = true;
    watchdog.restart();
  }

  // A process that cannot start only warns and never exits, so without this the panel
  // would sit on "Loading…" forever; it also catches a feed that will not answer.
  Timer {
    id: watchdog

    interval: 15000

    onTriggered: {
      if (!root.loading)
        return;
      fetch.running = false;
      root.loading = false;
      root.error = "The calendar did not answer in time.";
      var next = Object.assign({}, root.months);
      next[fetch.key] = [];
      root.months = next;
      root.finishPending();
    }
  }

  // Asked for by hand, so it goes past both caches.
  function refresh() {
    root.months = {};
    if (fetch.running) {
      root.pendingKey = root.monthKey;
      root.pendingForce = true;
      return;
    }
    root.load(true);
  }

  function finishPending() {
    if (root.pendingKey === "")
      return;
    root.pendingKey = "";
    var force = root.pendingForce;
    root.pendingForce = false;
    Qt.callLater(function () {
      root.load(force);
    });
  }

  Process {
    id: fetch

    property string key: ""

    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() === "") {
          root.loading = false;
          return;
        }
        var out = root.rows(text);

        var next = Object.assign({}, root.months);
        next[fetch.key] = out;
        watchdog.stop();
        root.months = next;
        root.error = "";
        root.loading = false;
      }
    }

    stderr: StdioCollector {}

    onExited: function (code) {
      watchdog.stop();
      root.loading = false;
      if (code === 0)
        root.finishPending();
      if (code === 0)
        return;
      // ical-agenda fails with one line, and it says it better than this could. The
      // stderr text may not have flushed by the time exit fires, so an empty line only
      // supplies the generic message when nothing else has said what went wrong.
      var said = fetch.stderr.text.trim().split("\n")[0];
      if (said !== "")
        root.error = said;
      else if (root.error === "")
        root.error = "The calendar is not set up";
      var next = Object.assign({}, root.months);
      next[fetch.key] = [];
      root.months = next;
      root.finishPending();
    }
  }

  // ical-agenda's TSV (a header line naming the columns, then one event a line) as events.
  function rows(text) {
    var lines = text.split("\n");

    var cols = {};
    var head = lines[0].split("\t");
    for (var c = 0; c < head.length; c++)
      cols[head[c].trim()] = c;

    function field(parts, name) {
      var i = cols[name];
      return i === undefined || i >= parts.length ? "" : parts[i].trim();
    }

    var out = [];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() === "")
        continue;
      var p = lines[i].split("\t");

      var sd = field(p, "start_date");
      if (sd === "")
        continue;
      var st = field(p, "start_time");
      var ed = field(p, "end_date");
      var et = field(p, "end_time");

      // ical-agenda leaves both times empty for an all-day event.
      var allDay = st === "";

      out.push({
        start: root.parse(sd, st),
        end: root.parse(ed !== "" ? ed : sd, et),
        allDay: allDay,
        title: field(p, "title"),
        calendar: field(p, "calendar"),
        location: field(p, "location")
      });
    }
    return out;
  }

  // Built field by field rather than handed to Date(), which parses a bare date as UTC
  // and would put a late evening event on the wrong day.
  function parse(date, time) {
    var d = date.split("-");
    var t = time !== "" ? time.split(":") : ["0", "0"];
    return new Date(parseInt(d[0], 10), parseInt(d[1], 10) - 1, parseInt(d[2], 10), parseInt(t[0], 10), parseInt(t[1], 10));
  }

  // ---- today, for the island ----

  // Today's events on a fetch of their own, apart from the month on screen, read again every five
  // minutes and at midnight. ical-agenda keeps the feed ten minutes, so most reads cost nothing.
  property var todayEvents: []

  // The event the hover card names: the first timed one today that has not ended, the one under
  // way included. All-day events are left out; they are the day, not a time in it.
  readonly property var nextEvent: {
    var now = clock.date;
    var tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    var best = null;
    for (var i = 0; i < root.todayEvents.length; i++) {
      var e = root.todayEvents[i];
      if (e.allDay || e.end <= now || e.start >= tomorrow)
        continue;
      if (best === null || e.start < best.start)
        best = e;
    }
    return best;
  }

  function loadToday() {
    if (todayFetch.running)
      return;
    var d = root.stamp(root.todayDate);
    todayFetch.command = ["ical-agenda", d, d];
    todayFetch.running = true;
  }

  onDayStampChanged: root.loadToday()

  Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.loadToday()
  }

  Process {
    id: todayFetch

    stdout: StdioCollector {
      onStreamFinished: root.todayEvents = text.trim() === "" ? [] : root.rows(text)
    }

    stderr: StdioCollector {}
  }

  Component.onCompleted: {
    root.load();
    root.loadToday();
  }
}
