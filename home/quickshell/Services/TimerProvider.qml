pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import "../Commons/Duration.js" as Duration

// The launcher's timer rows, an Omnibox provider: a plain "25m", "10 min", "timer 10", "1h30",
// "pomodoro" or "focus" offers to start a timer or the Pomodoro, and stop whichever is running,
// without a prefix. Enter acts through Services/Timers.qml and Services/Pomodoro.qml, so what
// starts here shows on the island like anything started by `qs ipc call timer`.
//
// It leaves other queries alone. A unit makes a query a timer's (score 90, which lifts the
// section); a bare number is only a guess at minutes (score 30, below the lift), so "10" still
// belongs to the calculator and the apps.
Singleton {
  id: root

  property string query: ""

  readonly property string section: "Timer"
  readonly property string prefix: ""

  readonly property int exactScore: 90
  readonly property int guessScore: 30

  // "timer" alone offers this.
  readonly property real defaultMs: 5 * 60000
  // A day is the longest a launcher timer runs; beyond it the number is something else.
  readonly property real longestMs: 24 * 3600000

  // The running things' clocks, once a second.
  readonly property int second: Math.floor(Math.max(Timers.now, Pomodoro.now) / 1000)

  readonly property var results: root.rowsFor(root.query, root.second)

  // What a query asks: { kind: "timer" | "pomodoro" | "stop", ms, exact } or null.
  function interpret(text) {
    var q = text.trim().toLowerCase();
    if (q === "")
      return null;
    if (/^(stop|cancel)$/.test(q))
      return {
        kind: "stop",
        ms: 0,
        exact: true
      };
    if (/^(pomodoro|pomo|focus)$/.test(q))
      return {
        kind: "pomodoro",
        ms: 0,
        exact: true
      };
    if (q === "timer")
      return {
        kind: "timer",
        ms: root.defaultMs,
        exact: true
      };
    var rest = q;
    var named = /^timer\s+(.+)$/.exec(q);
    if (named)
      rest = named[1];
    // Digits first, and either a unit or "timer" to say it is a length of time: a bare number
    // is minutes only as a guess.
    if (!/^\d/.test(rest))
      return null;
    var bare = /^\d+(\.\d+)?$/.test(rest);
    var ms = Duration.parse(rest);
    if (!bare && !/^[\d.]+\s*[hms]/.test(rest))
      return null;
    if (ms <= 0 || ms > root.longestMs)
      return null;
    return {
      kind: "timer",
      ms: ms,
      exact: named !== null || !bare
    };
  }

  // The rows' clock: "05:00", "08:12", "1:30:00"; the island's own reads "5:00".
  function clock(ms) {
    var s = Math.max(0, Math.ceil(ms / 1000));
    var h = Math.floor(s / 3600);
    var m = Math.floor(s / 60) % 60;
    return (h > 0 ? h + ":" : "") + Duration.pad(m) + ":" + Duration.pad(s % 60);
  }

  // Whether the query is plainly a timer's: a length with a unit, "timer", "pomodoro", "stop". A
  // bare number is not, so the calculator keeps it.
  function claims(text) {
    var ask = root.interpret(text);
    return ask !== null && ask.exact;
  }

  // The running timer that ends first, or null.
  function nearest() {
    var best = null;
    for (var i = 0; i < Timers.timers.length; i++) {
      var t = Timers.timers[i];
      if (best === null || Timers.remaining(t) < Timers.remaining(best))
        best = t;
    }
    return best;
  }

  function rowsFor(text, tick) {
    var ask = root.interpret(text);
    if (ask === null)
      return [];
    var rows = [];
    var top = ask.exact ? root.exactScore : root.guessScore;
    var running = root.nearest();

    if (ask.kind === "timer") {
      rows.push({
        id: "timer:start",
        name: "Start timer · " + root.clock(ask.ms),
        desc: "Counts down on the island",
        path: IconPaths.timer,
        tone: "accent",
        score: top,
        matches: [],
        act: "start",
        ms: ask.ms
      });
    }

    // Bare numbers are a guess; the other rows would only be noise under one.
    if (!ask.exact)
      return rows;

    if (ask.kind !== "stop" || Pomodoro.running)
      rows.push(root.pomodoroRow(top - 1, ask.kind === "stop"));
    if (running !== null)
      rows.push({
        id: "timer:stop",
        name: "Stop timer · " + root.clock(Timers.remaining(running)) + " left",
        desc: "Started " + Qt.formatTime(new Date(running.startedAt), "HH:mm") + " · " + root.clock(running.total),
        path: IconPaths.square,
        tone: "love",
        score: ask.kind === "stop" ? top : top - 2,
        matches: [],
        act: "stop",
        timerId: running.id
      });
    return rows;
  }

  // Starts the cycle, or stops the one running: a second Pomodoro would do nothing.
  function pomodoroRow(score, stopping) {
    if (Pomodoro.running)
      return {
        id: "timer:pomodoro-stop",
        name: "Stop Pomodoro · " + root.clock(Pomodoro.left) + " left",
        desc: Pomodoro.title(Pomodoro.phase) + " · " + Pomodoro.caption(),
        path: IconPaths.square,
        tone: "love",
        score: stopping ? score + 1 : score,
        matches: [],
        act: "pomodoro-stop"
      };
    return {
      id: "timer:pomodoro",
      name: "Start Pomodoro · " + Theme.pomodoroFocusMinutes + " / " + Theme.pomodoroShortBreakMinutes + " × " + Theme.pomodoroRounds,
      desc: "Four rounds of focus and break",
      path: IconPaths.repeat,
      tone: "accent",
      score: score,
      matches: [],
      act: "pomodoro"
    };
  }

  // Closes the launcher after each.
  function activate(row, modifiers) {
    if (row.act === "start")
      Timers.start(Math.round(row.ms / 1000) + "s", "");
    else if (row.act === "stop")
      Timers.cancel(row.timerId);
    else if (row.act === "pomodoro")
      Pomodoro.start();
    else if (row.act === "pomodoro-stop")
      Pomodoro.stop();
    return false;
  }
}
