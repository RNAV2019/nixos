pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The system rebuild that the `rebuild` alias (home/shell.nix) is running, as Nix reports it. The
// alias has Nix write its progress to a file (`--option json-log-path`, the JSON of
// `--log-format internal-json`); this tails that file and keeps what the pill in
// Rebuild/RebuildPill.qml shows: what the rebuild is doing, how far through the whole of it it is,
// then done or failed.
//
// A file, not a socket the shell listens on, because Nix falls back to a plain file when nothing
// listens (so a socket the shell dropped would be replaced by a root-owned file, and a stale one
// makes every Nix process print "error (ignored)"), and a shell that stopped reading would block
// the build on a full socket. A file can do neither: the rebuild is unchanged whether or not the
// shell runs, and the shell only ever reads. It is root's (the build is under sudo), in the
// user's runtime directory, and removed here when a run ends, so it does not grow. A run the
// shell was not there for is left in it and skipped: tailing starts at the end.
//
// What is read, of the events Nix writes (one JSON object a line):
// - the first event of a run starts the pill; the nix processes of one rebuild (nixos-rebuild runs
//   several, one after another) share the file, told apart by the pid in the top half of every
//   activity id;
// - every realisation's `builds` and `copy paths` activities (types 104 and 103) report
//   [done, expected, running, failed] (results of type 105); their sums are `done` and `total`.
//   That includes the realisations evaluation itself asks for: this configuration grafts GTK with
//   system.replaceDependencies, which builds the ungrafted system while it evaluates, so most
//   building happens before the "these N derivations will be built" of the last realisation;
// - a `build` or `substitute` activity (105, 108) open means something is being built or fetched;
// - a message of level 0 that starts "error" (not "error (ignored)") and a build that failed
//   (field 3) mean failure;
// - the run is over when none of its processes is alive and the log has been quiet a moment (the
//   next nix process of the same rebuild starts within that). It failed if an error was seen, or
//   an activity was still open (a process that ended without a result: killed, or Ctrl-C), else
//   it is done. nixos-rebuild (found by the log path in its command line) counts as one of them,
//   so a switch is done once its activation has run too (whether that worked is only in the
//   terminal).
//
// How far it is: Nix never knows the whole of it in advance (evaluation's builds are found as it
// goes, and activation writes nothing to the log), so `progress` is the work credited so far over
// the work expected, each measured in time:
// - evaluating, the time the Nix processes ran with nothing building, against what evaluation
//   took last time. Nix says nothing of how far it is, but a configuration starts about the same
//   number of activities (sources copied to the store) each time it is evaluated, so the time
//   leads, held within reach of that count;
// - building, the time spent so far, expecting as much again for each derivation or path still
//   to come as one took last time;
// - activating, while only nixos-rebuild is left (switch-to-configuration), the time against the
//   last activation's.
// Work found on the way grows what is expected, so the bar holds rather than going back; work
// that runs over its estimate creeps towards its end instead of reaching it. The lengths are
// learned from the runs that worked (Paths.stateDir/rebuild.json); until there is one, rough
// defaults stand in.
Job {
  id: root

  // The alias passes the same path.
  readonly property string logPath: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/rebuild.jsonl"

  // The user has dismissed the finished or failed run.
  property bool dismissed: false

  readonly property bool shown: phase !== "" && !dismissed

  // "evaluating", "building" or "activating": what it is doing; after a run, what it was.
  property string step: ""

  // How far through the whole rebuild, 0 to 1; 1 once it is done.
  property real progress: 0

  // How long the log must have been quiet, with no process alive, to call a run over.
  property int quietMs: 2500

  function dismiss() {
    dismissed = true;
  }

  // ---- reading ----

  // The run's processes: true for a Nix process in the log, "parent" for the nixos-rebuild given
  // the log, which is not in it but outlives them through the activation.
  property var _pids: ({})
  property var _open: ({})
  property int _openCount: 0
  // Each builds and copy-paths activity's latest [done, expected], by id, from when it starts.
  // Activity ids carry the pid in their top half, so they do not fit an int.
  property var _units: ({})
  // The build and substitute activities open, and when the last one closed.
  property var _work: ({})
  property int _workCount: 0
  property real _workEndedAt: 0
  property real _lastEvent: 0
  // When a probe last found one of the run's processes alive.
  property real _lastAlive: 0
  property bool _failed: false
  // Activities this run started that are not builds or fetches (mostly evaluation copying sources
  // to the store).
  property int _events: 0
  // What nixos-rebuild was asked to do, read from its command line once a probe finds it.
  property string _action: "switch"
  // Only nixos-rebuild is left.
  property bool _activating: false
  // The time spent evaluating, building and activating, added up a tick at a time.
  property real _evalMs: 0
  property real _buildMs: 0
  property real _activateMs: 0
  property real _tickAt: 0

  function _strip(text) {
    return String(text).replace(/\u001b\[[0-9;]*m/g, "");
  }

  function _begin() {
    phase = "running";
    startedAt = Date.now();
    endedAt = 0;
    done = 0;
    total = 0;
    progress = 0;
    step = "evaluating";
    dismissed = false;
    _pids = {};
    _lastAlive = 0;
    _open = {};
    _openCount = 0;
    _units = {};
    _work = {};
    _workCount = 0;
    _workEndedAt = 0;
    _failed = false;
    _events = 0;
    _action = "switch";
    _activating = false;
    _evalMs = 0;
    _buildMs = 0;
    _activateMs = 0;
    _tickAt = startedAt;
  }

  // One line of the log.
  function read(line) {
    var e;
    try {
      e = JSON.parse(line);
    } catch (err) {
      return;
    }
    if (e === null || typeof e !== "object")
      return;
    if (phase !== "running")
      _begin();
    _lastEvent = Date.now();

    if (e.id !== undefined) {
      var pid = Math.floor(e.id / 4294967296);
      if (_pids[pid] === undefined) {
        var seen = Object.assign({}, _pids);
        seen[pid] = true;
        _pids = seen;
      }
    }

    switch (e.action) {
    case "start":
      if (_open[e.id] === undefined) {
        _open[e.id] = true;
        _openCount++;
      }
      if (e.type === 103 || e.type === 104) {
        _units[e.id] = [0, 0];
      } else if (e.type === 105 || e.type === 108) {
        _tick();
        _work[e.id] = true;
        _workCount++;
      } else if (e.type === 0) {
        _events++;
      }
      break;
    case "stop":
      if (_open[e.id] !== undefined) {
        delete _open[e.id];
        _openCount--;
      }
      if (_work[e.id] !== undefined) {
        _tick();
        delete _work[e.id];
        _workCount--;
        _workEndedAt = Date.now();
      }
      break;
    case "result":
      // Progress of a realisation's builds or fetches: [done, expected, running, failed]. Copying
      // a path and downloading report progress too, but in bytes.
      if (e.type === 105 && _units[e.id] !== undefined && e.fields !== undefined && e.fields.length >= 4) {
        _units[e.id] = [e.fields[0], e.fields[1]];
        _count();
        if (e.fields[3] > 0)
          _failed = true;
      }
      break;
    case "msg":
      if (e.level === 0 && /^error\b(?! \(ignored\))/.test(_strip(e.msg)))
        _failed = true;
      break;
    }
  }

  function _count() {
    var d = 0, t = 0;
    for (var id in _units) {
      var u = _units[id];
      d += Math.min(u[0], u[1]);
      t += u[1];
    }
    done = d;
    total = t;
  }

  // ---- how far ----

  // What the last runs that worked took; read from and written to `history`.
  property var _hist: ({})

  // A rough first guess, on a laptop, until a run has been measured.
  readonly property real _defaultEvalMs: 25000
  readonly property real _defaultStepMs: 4000
  readonly property real _defaultActivateMs: 8000

  // How long one derivation built or path fetched takes.
  readonly property real _stepMs: _hist.stepMs || _defaultStepMs

  // How long activation takes, 0 for a build or dry run, which has nothing after Nix.
  function _expectedActivation() {
    if (_action !== "switch" && _action !== "test" && _action !== "boot")
      return 0;
    var a = _hist.activateMs || {};
    return a[_action] || _defaultActivateMs;
  }

  // Elapsed over expected, as a fraction that tracks it until 0.8 and then slows towards 0.97,
  // so an overrun creeps rather than stops.
  function _eased(elapsed, expected) {
    if (expected <= 0)
      return 0;
    var x = elapsed / expected;
    if (x < 0.8)
      return x;
    return 0.8 + 0.17 * (1 - Math.exp(-(x - 0.8) / 0.17));
  }

  // Adds the time since the last tick to what was going on through it.
  function _tick() {
    var now = Date.now();
    var dt = Math.max(0, now - _tickAt);
    _tickAt = now;
    if (phase !== "running")
      return;
    if (_activating)
      _activateMs += dt;
    else if (_workCount > 0)
      _buildMs += dt;
    else
      _evalMs += dt;
  }

  function _advance() {
    _tick();
    var now = Date.now();
    step = _activating ? "activating" : (_workCount > 0 || now - _workEndedAt < 1000) ? "building" : "evaluating";

    // Evaluation is all done once Nix is.
    var e = _hist.evalMs || _defaultEvalMs;
    var evaluated = 1;
    if (!_activating) {
      var byTime = _eased(_evalMs, e);
      evaluated = byTime;
      // The count comes in bursts with long quiet stretches between, so the time leads, but no
      // further than a fifth of evaluation past the count.
      if (_hist.evalEvents) {
        var byCount = Math.min(1, _events / _hist.evalEvents);
        evaluated = Math.min(0.97, Math.max(byCount, Math.min(byTime, byCount + 0.2)));
      }
    }
    var pending = Math.max(0, total - done) * _stepMs;
    var a = _expectedActivation();
    var activated = _activating ? a * _eased(_activateMs, a) : 0;

    var p = (e * evaluated + _buildMs + activated) / (e + _buildMs + pending + a);
    if (p > progress)
      progress = Math.min(0.99, p);
  }

  Timer {
    interval: 200
    repeat: true
    running: root.running
    onTriggered: root._advance()
  }

  // Keeps what a run that worked took, for the next run's estimates.
  function _learn() {
    var h = Object.assign({}, _hist);
    // Halfway between the last estimate and this run, so one slow run (a cold cache, inputs to
    // fetch) does not throw the next one far off.
    var blend = (old, now) => Math.round(old ? (old + now) / 2 : now);
    // An evaluation Nix had cached starts next to nothing and says nothing of the next one.
    if (!h.evalEvents || _events >= h.evalEvents / 2) {
      h.evalMs = blend(h.evalMs, _evalMs);
      h.evalEvents = blend(h.evalEvents, _events);
    }
    if (_buildMs > 0 && done > 0)
      h.stepMs = blend(h.stepMs, _buildMs / done);
    if (_activateMs > 0 && _expectedActivation() > 0) {
      var a = Object.assign({}, h.activateMs || {});
      a[_action] = blend(a[_action], _activateMs);
      h.activateMs = a;
    }
    _hist = h;
    history.save(JSON.stringify(h, null, 2));
  }

  PersistedValue {
    id: history

    name: "rebuild.json"

    onRestored: text => {
      try {
        root._hist = JSON.parse(text) || {};
      } catch (e) {
        root._hist = {};
      }
    }
  }

  // ---- ending ----

  // Ticks while a run is on: asks which of its processes are alive, and ends it once none is and
  // the log has been quiet.
  Timer {
    interval: 1000
    repeat: true
    running: root.running
    onTriggered: root._probe()
  }

  function _probe() {
    if (probe.running)
      return;
    // Prints the live ones of the run's processes, then every process with this log in its
    // command line as "parent <pid>" and its arguments, tab-separated; which of those are
    // nixos-rebuild is up to `_isRebuild`. Found by command line rather than as a Nix process's
    // parent, since a Nix process with nothing to do can be gone before tail has even seen the
    // file.
    probe.command = ["sh", "-c", "log=$1; shift; for p; do [ -d /proc/$p ] && echo $p; done; for f in $(grep -laF -- \"$log\" /proc/[0-9]*/cmdline 2>/dev/null); do p=${f#/proc/}; p=${p%/cmdline}; [ $p = $$ ] && continue; printf 'parent %s\\t' $p; tr '\\0\\n' '\\t ' < $f 2>/dev/null; echo; done", "sh", logPath].concat(Object.keys(_pids));
    probe.running = true;
  }

  // nixos-rebuild (or the sudo that runs it, which lives as long) given this log: the program and
  // the path as arguments of their own, so a shell whose script merely mentions both is not.
  function _isRebuild(args) {
    return args.indexOf(logPath) >= 0 && args.some(a => /(?:^|\/)\.?nixos-rebuild(?:-wrapped)?$/.test(a));
  }

  Process {
    id: probe

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.phase !== "running")
          return;
        var lines = text.trim() === "" ? [] : text.trim().split("\n");
        var parents = null;
        var alive = false;
        var nixAlive = false;
        for (var i = 0; i < lines.length; i++) {
          // A process gone before its command line was read (the probe's own grep, which has
          // the path as an argument) leaves "parent <pid>" alone.
          var m = /^parent (\d+)(?:\t(.*))?$/.exec(lines[i]);
          if (m === null) {
            alive = true;
            if (root._pids[lines[i]] === true)
              nixAlive = true;
            continue;
          }
          var args = (m[2] || "").split("\t");
          if (root._pids[m[1]] !== undefined || !root._isRebuild(args))
            continue;
          alive = true;
          parents = parents || Object.assign({}, root._pids);
          parents[m[1]] = "parent";
          var action = args.find(a => /^(?:switch|boot|test|build|dry-build|dry-activate|build-vm|build-vm-with-bootloader|build-image)$/.test(a));
          if (action !== undefined)
            root._action = action;
        }
        if (parents !== null)
          root._pids = parents;
        // Only nixos-rebuild is left: switch-to-configuration.
        if (alive && !nixAlive && !root._activating && root._expectedActivation() > 0) {
          root._tick();
          root._activating = true;
        }
        if (alive)
          root._lastAlive = Date.now();
        else if (Date.now() - root._lastEvent >= root.quietMs)
          root._finish();
      }
    }
  }

  function _finish() {
    _tick();
    endedAt = Math.max(_lastEvent, _lastAlive);
    var failed = _failed || _openCount > 0;
    if (!failed) {
      done = total;
      progress = 1;
      // The quiet wait before this is not the rebuild's.
      var over = Math.max(0, Date.now() - endedAt);
      if (_activating)
        _activateMs = Math.max(0, _activateMs - over);
      else
        _evalMs = Math.max(0, _evalMs - over);
      _learn();
    }
    phase = failed ? "failed" : "done";
    // Done with: no process has it open, and the next run starts a new one.
    cleaner.exec(["rm", "-f", logPath]);
  }

  Command {
    id: cleaner

    label: "Rebuild log cleanup"
  }

  // ---- the file ----

  // From the end of the file as it is now, and over any replacement of it (a new file is read
  // from its start). Ends with the shell, and is started again if it ever ends without it.
  // Until the first run there is no file, which tail says once and waits for.
  Stream {
    command: ["tail", "-n0", "-F", "--pid=" + Quickshell.processId, root.logPath]
    retryMs: 5000

    onLine: text => root.read(text)
  }
}
