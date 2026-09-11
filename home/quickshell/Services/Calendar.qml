pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Google Calendar, read through ical-agenda. Board 14.
//
// The Google side is a secret iCal address held in secrets/secrets.yaml: sops-nix
// decrypts it to a root-written file that only ical-agenda opens, so there is no OAuth
// client and no refresh token, and nothing here ever sees an address.
//
// ical-agenda does the fetching, the recurrence expansion and the merge, and prints TSV.
// See home/ical-agenda.nix. Events are read a month at a time and cached by month key.
Singleton {
  id: root

  // The month on screen, as the first of that month.
  property date anchor: {
    var now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  }

  // Which day the agenda below the grid is for.
  property date selected: new Date()

  property bool loading: false

  // Set when ical-agenda cannot answer, which on a fresh machine means no address yet.
  property string error: ""

  // month key -> array of events. An event is
  // { start: Date, end: Date, allDay: bool, title, calendar, location }.
  property var months: ({})

  readonly property string monthKey: root.keyFor(root.anchor)

  readonly property var events: root.months[root.monthKey] || []

  function keyFor(d) {
    return d.getFullYear() + "-" + (d.getMonth() + 1);
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  // The events on one day, in start order, all-day first.
  function eventsOn(day) {
    var out = [];
    for (var i = 0; i < root.events.length; i++) {
      if (root.sameDay(root.events[i].start, day))
        out.push(root.events[i]);
    }
    out.sort(function (a, b) {
      if (a.allDay !== b.allDay)
        return a.allDay ? -1 : 1;
      return a.start - b.start;
    });
    return out;
  }

  function hasEvents(day) {
    for (var i = 0; i < root.events.length; i++) {
      if (root.sameDay(root.events[i].start, day))
        return true;
    }
    return false;
  }

  // A stable colour per calendar, independent of which event arrived first.
  function colourFor(name) {
    var palette = [Theme.foam, Theme.iris, Theme.gold, Theme.rose, Theme.pine];
    if (!name)
      return palette[0];
    var h = 0;
    for (var i = 0; i < name.length; i++)
      h = (h * 31 + name.charCodeAt(i)) % 997;
    return palette[h % palette.length];
  }

  function step(months) {
    var d = new Date(root.anchor.getFullYear(), root.anchor.getMonth() + months, 1);
    root.anchor = d;
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

  // The grid draws days from the neighbouring months, so the fetch is padded a week
  // either side.
  // `force` is the user asking again rather than the grid moving, and goes down as
  // --refresh so the feeds are re-downloaded.
  function load(force) {
    if (root.months[root.monthKey] !== undefined)
      return;
    var from = new Date(root.anchor.getFullYear(), root.anchor.getMonth(), 1 - 7);
    var to = new Date(root.anchor.getFullYear(), root.anchor.getMonth() + 1, 7);
    root.loading = true;
    fetch.key = root.monthKey;
    fetch.command = ["ical-agenda"].concat(force ? ["--refresh"] : []).concat([root.stamp(from), root.stamp(to)]);
    fetch.running = true;
    watchdog.restart();
  }

  // A process that cannot start at all only warns and never exits, so without this the
  // panel would sit on "Loading…" forever. It also catches a feed that will not answer.
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
    }
  }

  // Asked for by hand, so it goes past both caches.
  function refresh() {
    root.months = {};
    root.load(true);
  }

  Process {
    id: fetch

    property string key: ""

    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n");
        if (lines.length === 0) {
          root.loading = false;
          return;
        }

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
        return;
      // ical-agenda fails with one line, and it says it better than this could.
      var said = fetch.stderr.text.trim().split("\n")[0];
      root.error = said === "" ? "The calendar is not set up" : said;
      var next = Object.assign({}, root.months);
      next[fetch.key] = [];
      root.months = next;
    }
  }

  // Built field by field rather than handed to Date(), which parses a bare date string
  // as UTC and would put a late evening event on the wrong day.
  function parse(date, time) {
    var d = date.split("-");
    var t = time !== "" ? time.split(":") : ["0", "0"];
    return new Date(parseInt(d[0], 10), parseInt(d[1], 10) - 1, parseInt(d[2], 10), parseInt(t[0], 10), parseInt(t[1], 10));
  }

  Component.onCompleted: root.load()
}
