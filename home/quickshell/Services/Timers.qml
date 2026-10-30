pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Duration.js" as Duration

// Countdown timers, as many as you like: `qs ipc call timer start 10m Pasta`. Each is an
// activity on the island (Activities/TimerSource.qml draws it) and raises a "Timer done"
// moment when it runs out. Times are absolute (`endsAt`), so nothing drifts with the tick
// and a running timer survives a shell reload: the set is saved to a state file on every
// change and read back at startup, where one that ran out in the last minute still rings.
Singleton {
  id: root

  // One per timer: { id, label, total, endsAt, remaining, paused, startedAt }, in ms. Replaced
  // wholesale on every change, never mutated.
  property var timers: []

  // The tick the readings are taken against.
  property real now: Date.now()

  property int _lastId: 0

  // One row per timer id, kept in step with `timers` so the island's Instantiator adds and
  // removes activities one by one instead of rebuilding them all.
  readonly property alias ids: idModel

  ListModel {
    id: idModel
  }

  function byId(id) {
    for (var i = 0; i < timers.length; i++) {
      if (timers[i].id === id)
        return timers[i];
    }
    return null;
  }

  function remaining(t) {
    if (!t)
      return 0;
    return t.paused ? t.remaining : Math.max(0, t.endsAt - now);
  }

  function endsText(t) {
    return t ? Qt.formatTime(new Date(t.endsAt), "HH:mm") : "";
  }

  // ---- control ----

  // "90s", "10m", "1h30m" or a bare number of minutes. Returns the new timer's id, 0 if the
  // duration was not one.
  function start(spec, label) {
    var ms = Duration.parse(spec);
    if (ms <= 0)
      return 0;
    var t = {
      id: ++_lastId,
      label: label ? String(label).trim() : "",
      total: ms,
      endsAt: Date.now() + ms,
      remaining: ms,
      paused: false,
      startedAt: Date.now()
    };
    now = Date.now();
    _commit(timers.concat([t]));
    return t.id;
  }

  // For all of these an id of 0 means every timer.
  function pause(id) {
    _each(id, function (t) {
      if (t.paused)
        return t;
      return _with(t, {
        paused: true,
        remaining: Math.max(0, t.endsAt - Date.now())
      });
    });
  }

  function resume(id) {
    _each(id, function (t) {
      if (!t.paused)
        return t;
      return _with(t, {
        paused: false,
        endsAt: Date.now() + t.remaining
      });
    });
  }

  // Adds time to the running or paused timer, and to its total, so the ring keeps its meaning.
  function add(id, spec) {
    var ms = Duration.parse(spec);
    if (ms <= 0)
      return false;
    _each(id, function (t) {
      return _with(t, {
        total: t.total + ms,
        endsAt: t.endsAt + ms,
        remaining: t.remaining + ms
      });
    });
    return true;
  }

  function cancel(id) {
    _commit(timers.filter(function (t) {
      return id !== 0 && t.id !== id;
    }));
  }

  function describe() {
    var lines = [];
    for (var i = 0; i < timers.length; i++) {
      var t = timers[i];
      lines.push(t.id + "\t" + Duration.clock(remaining(t)) + "\t" + (t.paused ? "paused" : "running") + "\t" + Duration.describe(t.total) + (t.label !== "" ? "\t" + t.label : ""));
    }
    return lines.join("\n");
  }

  function _with(t, changes) {
    var next = {};
    for (var k in t)
      next[k] = t[k];
    for (var c in changes)
      next[c] = changes[c];
    return next;
  }

  function _each(id, change) {
    now = Date.now();
    _commit(timers.map(function (t) {
      return id === 0 || t.id === id ? change(t) : t;
    }));
  }

  // Replaces the set, keeps the id rows in step and saves.
  function _commit(next) {
    timers = next;
    for (var i = idModel.count - 1; i >= 0; i--) {
      var found = false;
      for (var j = 0; j < next.length; j++) {
        if (next[j].id === idModel.get(i).tid)
          found = true;
      }
      if (!found)
        idModel.remove(i);
    }
    for (var n = 0; n < next.length; n++) {
      var present = false;
      for (var r = 0; r < idModel.count; r++) {
        if (idModel.get(r).tid === next[n].id)
          present = true;
      }
      if (!present)
        idModel.append({
          tid: next[n].id
        });
    }
    store.setText(JSON.stringify(next));
  }

  // ---- running out ----

  function _finish(t) {
    var what = Duration.describe(t.total);
    Activities.raiseMoment({
      kind: "timer-done",
      attention: true,
      icon: IconPaths.timer,
      iconColor: Theme.gold,
      title: "Timer done",
      subtitle: t.label !== "" ? t.label + " · " + what : what,
      // The alarm sound loops until this is answered: Activities.momentRaised is the hook.
      dwell: 0,
      buttons: [
        {
          text: "+5 min",
          width: 68,
          kind: "secondary",
          action: function () {
            root.start("5m", t.label);
          }
        },
        {
          text: "Dismiss",
          width: 72,
          kind: "primary"
        }
      ]
    });
  }

  function _tick() {
    now = Date.now();
    var done = timers.filter(function (t) {
      return !t.paused && t.endsAt <= now;
    });
    if (done.length === 0)
      return;
    _commit(timers.filter(function (t) {
      return t.paused || t.endsAt > now;
    }));
    for (var i = 0; i < done.length; i++)
      _finish(done[i]);
  }

  Timer {
    interval: 250
    running: root.timers.length > 0
    repeat: true
    onTriggered: root._tick()
  }

  // ---- surviving a reload ----

  FileView {
    id: store

    path: Paths.stateDir + "/timers.json"
    // Read at once, so a timer started the instant the shell comes up cannot overwrite them.
    blockLoading: true
    printErrors: false

    onLoaded: {
      var saved = [];
      try {
        saved = JSON.parse(store.text()) || [];
      } catch (e) {
        saved = [];
      }
      if (root.timers.length > 0 || !Array.isArray(saved))
        return;
      var cutoff = Date.now() - 60000;
      var live = [];
      var rung = [];
      for (var i = 0; i < saved.length; i++) {
        var t = saved[i];
        root._lastId = Math.max(root._lastId, t.id);
        if (t.paused || t.endsAt > Date.now())
          live.push(t);
        else if (t.endsAt > cutoff)
          rung.push(t);
      }
      root._commit(live);
      for (var r = 0; r < rung.length; r++)
        root._finish(rung[r]);
    }
  }
}
