pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Google Calendar, read through ical-agenda. Board 14.
//
// The Google side is a secret iCal address: a URL that returns an .ics for one
// calendar, issued and revoked from Google's own settings panel. There is no
// OAuth client, no consent and no refresh token, which is the whole reason it
// replaced gcalcli - a token in a folder the shell can read is a credential
// the shell is responsible for, and this is one line in secrets/secrets.yaml
// instead. sops-nix decrypts the addresses to a root-written file that only
// ical-agenda opens; nothing here ever sees one.
//
// ical-agenda does the fetching, the recurrence expansion and the merge across
// calendars, and prints the same TSV gcalcli did. See home/ical-agenda.nix.
//
// Events are read a month at a time, because that is the unit the grid draws.
// Moving to another month is a new call; the answers are cached by month key so
// paging back and forth does not re-fetch, and ical-agenda keeps its own short
// cache of the feeds themselves underneath that.
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

  // Empty while things are working. Set when ical-agenda cannot answer, which
  // on a fresh machine means no address has been put in secrets.yaml yet.
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

  // The events on one day, in start order. All-day events come first, which is
  // the order a day reads in.
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

  // A stable colour per calendar, so the same calendar is the same colour every
  // session rather than depending on which event arrived first. The same trick
  // NotificationStore uses for avatars.
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

  // The grid shows leading and trailing days from the neighbouring months, so
  // the fetch is padded a week either side rather than being the month exactly.
  //
  // `force` is the user asking again rather than the grid moving, and it is
  // passed down as --refresh so the feeds are re-downloaded instead of being
  // answered out of ical-agenda's own cache.
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

  // A process that cannot start at all - no ical-agenda on PATH - only warns
  // and never exits, so nothing here would ever come back and the panel would
  // sit on "Loading…" for the rest of the session. This is also what catches a
  // feed on a network that is not answering.
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

  // Asked for by hand, so it goes past both caches: the months held here and
  // the feeds ical-agenda keeps on disk.
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

        // The header names the columns; everything below is read through it.
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

          // ical-agenda leaves both times empty for an all-day event, which is
          // the only thing that distinguishes one here.
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
      // ical-agenda fails with one line, whether that is a missing address
      // list on a machine that has never been set up or a feed that would not
      // answer. Either way it says it better than this could.
      var said = fetch.stderr.text.trim().split("\n")[0];
      root.error = said === "" ? "The calendar is not set up" : said;
      var next = Object.assign({}, root.months);
      next[fetch.key] = [];
      root.months = next;
    }
  }

  // "YYYY-MM-DD" and "HH:MM" as ical-agenda prints them. Built field
  // by field rather than handed to Date(), which parses a bare date string as
  // UTC and would put a late evening event on the wrong day.
  function parse(date, time) {
    var d = date.split("-");
    var t = time !== "" ? time.split(":") : ["0", "0"];
    return new Date(parseInt(d[0], 10), parseInt(d[1], 10) - 1, parseInt(d[2], 10), parseInt(t[0], 10), parseInt(t[1], 10));
  }

  Component.onCompleted: root.load()
}
