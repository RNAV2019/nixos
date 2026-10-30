pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Duration.js" as Duration

// A Pomodoro cycle: focus 25, short break 5, four rounds, then a long break 15 and round one
// again (the lengths are Theme tokens). `qs ipc call pomodoro start|pause|resume|skip|stop`.
// One activity on the island (Activities/PomodoroSource.qml); each phase that runs out by itself
// raises a moment saying what comes next, and the next phase is already running. Skipping and
// stopping are the user's own and say nothing. Like the timers it keeps absolute times and a
// state file, so it survives a shell reload.
Singleton {
  id: root

  // For tests only: QUICKSHELL_POMODORO_SPEEDUP=60 makes a "minute" a second.
  readonly property real speedup: Math.max(1, Number(Quickshell.env("QUICKSHELL_POMODORO_SPEEDUP")) || 1)
  readonly property real minuteMs: 60000 / speedup

  property bool running: false
  // "focus", "short" or "long".
  property string phase: "focus"
  // 1..rounds; the round the current phase belongs to.
  property int round: 1
  property real total: 0
  property real endsAt: 0
  property real remaining: 0
  // When the cycle started, for the satellite's place among the others.
  property real since: 0
  property bool paused: false

  property real now: Date.now()

  readonly property int rounds: Theme.pomodoroRounds
  readonly property bool focus: phase === "focus"
  readonly property real left: !running ? 0 : paused ? remaining : Math.max(0, endsAt - now)

  // Rounds finished so far, for the cycle dots: the current focus round does not count yet;
  // a break follows one that did.
  readonly property int doneRounds: phase === "long" ? rounds : focus ? round - 1 : round

  function lengthOf(p) {
    var minutes = p === "focus" ? Theme.pomodoroFocusMinutes : p === "short" ? Theme.pomodoroShortBreakMinutes : Theme.pomodoroLongBreakMinutes;
    return minutes * minuteMs;
  }

  function title(p) {
    return p === "focus" ? "Focus" : p === "short" ? "Short break" : "Long break";
  }

  function nextPhase() {
    if (focus)
      return round >= rounds ? "long" : "short";
    return "focus";
  }

  function nextRound() {
    return phase === "long" ? 1 : focus ? round : round + 1;
  }

  // "Round 2 of 4", or what the long break says it is.
  function caption() {
    return phase === "long" ? "Cycle complete" : "Round " + round + " of " + rounds;
  }

  // When the next phase starts, and what it is, for the card's right-hand line.
  function nextText() {
    if (paused)
      return "Paused";
    var next = nextPhase();
    return (next === "focus" ? "Focus" : "Break") + " at " + Qt.formatTime(new Date(endsAt), "HH:mm");
  }

  // ---- control ----

  function start() {
    if (running)
      return;
    running = true;
    since = Date.now();
    _enter("focus", 1);
  }

  function pause() {
    if (!running || paused)
      return;
    now = Date.now();
    remaining = Math.max(0, endsAt - now);
    paused = true;
    _save();
  }

  function resume() {
    if (!running || !paused)
      return;
    endsAt = Date.now() + remaining;
    paused = false;
    now = Date.now();
    _save();
  }

  // The user moving on; no moment, they know.
  function skip() {
    if (!running)
      return;
    _enter(nextPhase(), nextRound());
  }

  function stop() {
    running = false;
    paused = false;
    _save();
  }

  function describe() {
    if (!running)
      return "stopped";
    return title(phase) + "\t" + Duration.clock(left) + "\t" + caption() + (paused ? "\tpaused" : "");
  }

  function _enter(p, r) {
    phase = p;
    round = r;
    total = lengthOf(p);
    now = Date.now();
    endsAt = now + total;
    remaining = total;
    paused = false;
    _save();
  }

  // ---- running out ----

  function _elapsed() {
    var to = nextPhase();
    var done = round;
    var nextR = nextRound();
    _enter(to, nextR);
    var focusNext = to === "focus";
    Activities.raiseMoment({
      kind: "pomodoro-phase",
      key: "pomodoro-phase",
      attention: true,
      icon: focusNext ? IconPaths.timer : IconPaths.coffee,
      iconColor: focusNext ? Theme.gold : Theme.foam,
      title: focusNext ? "Break over — focus time" : "Focus done — " + (to === "long" ? Theme.pomodoroLongBreakMinutes : Theme.pomodoroShortBreakMinutes) + " min break",
      subtitle: (focusNext ? "Round " + nextR + " of " + rounds + " · focus running" : (to === "long" ? "Cycle complete" : "Round " + done + " of " + rounds) + " · break running"),
      dwell: Theme.pomodoroMomentDwell,
      buttons: [
        {
          text: "Skip",
          width: 60,
          kind: "ghost",
          action: function () {
            root.skip();
          }
        }
      ]
    });
  }

  function _tick() {
    now = Date.now();
    if (running && !paused && endsAt <= now)
      _elapsed();
  }

  Timer {
    interval: 250
    running: root.running && !root.paused
    repeat: true
    onTriggered: root._tick()
  }

  // ---- surviving a reload ----

  function _save() {
    store.setText(JSON.stringify({
      running: running,
      phase: phase,
      round: round,
      total: total,
      endsAt: endsAt,
      remaining: remaining,
      paused: paused,
      since: since
    }));
  }

  FileView {
    id: store

    path: Paths.stateDir + "/pomodoro.json"
    blockLoading: true
    printErrors: false

    onLoaded: {
      var saved = null;
      try {
        saved = JSON.parse(store.text());
      } catch (e) {
        saved = null;
      }
      if (!saved || !saved.running || root.running)
        return;
      // A cycle left running while the shell was off for longer than a minute is not resumed.
      if (!saved.paused && saved.endsAt < Date.now() - 60000)
        return;
      root.phase = saved.phase;
      root.round = saved.round;
      root.total = saved.total;
      root.endsAt = saved.endsAt;
      root.remaining = saved.remaining;
      root.paused = saved.paused;
      root.since = saved.since || Date.now();
      root.running = true;
      root.now = Date.now();
    }
  }
}
