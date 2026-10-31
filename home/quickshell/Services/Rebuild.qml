pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The system rebuild that the `rebuild` alias (home/shell.nix) is running, as Nix reports it. The
// alias has Nix write its progress to a file (`--option json-log-path`, the JSON of
// `--log-format internal-json`); this tails that file and keeps what the pill in
// Rebuild/RebuildPill.qml shows: building n of m derivations, then done or failed.
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
// - "these N derivations will be built" plus "these M paths will be fetched" is the total, as
//   Nix's own "x/y built, a/b copied" counts both. Nix's expected counts (field 1 of the progress
//   of the `builds` activity, type 104, and `copy paths`, 103) are not used: they count
//   evaluation-time work and swing up and down, so only their `done` (field 0, a result of type
//   105) is, of the activities started after those messages. Until a message there is no total,
//   which is the pill's evaluating state;
// - a message of level 0 that starts "error" (not "error (ignored)") and a build that failed
//   (field 3) mean failure;
// - the run is over when none of its processes is alive and the log has been quiet a moment (the
//   next nix process of the same rebuild starts within that). It failed if an error was seen, or
//   an activity was still open (a process that ended without a result: killed, or Ctrl-C), else
//   it is done. The Nix processes' parent, nixos-rebuild, counts as one of them, so a switch is
//   done once its activation has run too (whether that worked is only in the terminal).
Job {
  id: root

  // The alias passes the same path.
  readonly property string logPath: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/rebuild.jsonl"

  // The user has dismissed the finished or failed run.
  property bool dismissed: false

  readonly property bool shown: phase !== "" && !dismissed

  // How long the log must have been quiet, with no process alive, to call a run over.
  property int quietMs: 2500

  function dismiss() {
    dismissed = true;
  }

  // ---- reading ----

  // The run's processes: true for a Nix process in the log, "parent" for the nixos-rebuild that
  // started one, which is not in the log but outlives them through the activation.
  property var _pids: ({})
  property var _open: ({})
  property int _openCount: 0
  // The realisation Nix announced last: how many derivations it builds and paths it fetches,
  // and the activities that count them. Activity ids carry the pid in their top half, so they
  // do not fit an int.
  property int _toBuild: 0
  property int _toFetch: 0
  property real _buildId: 0
  property real _copyId: 0
  property int _built: 0
  property int _fetched: 0
  // A realisation has been announced, so the next builds and copy-paths activities are its.
  property bool _announced: false
  property real _lastEvent: 0
  // When a probe last found one of the run's processes alive.
  property real _lastAlive: 0
  property bool _failed: false

  function _strip(text) {
    return String(text).replace(/\u001b\[[0-9;]*m/g, "");
  }

  function _begin() {
    phase = "running";
    startedAt = Date.now();
    endedAt = 0;
    done = 0;
    total = 0;
    dismissed = false;
    _pids = {};
    _lastAlive = 0;
    _open = {};
    _openCount = 0;
    _resetRealisation();
    _failed = false;
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
      // The builds and fetches of the realisation announced above, not the ones evaluation made.
      if (e.type === 104 && _buildId === 0 && _announced)
        _buildId = e.id;
      else if (e.type === 103 && _copyId === 0 && _announced)
        _copyId = e.id;
      break;
    case "stop":
      if (_open[e.id] !== undefined) {
        delete _open[e.id];
        _openCount--;
      }
      break;
    case "result":
      // Progress of the builds or the fetches: [done, expected, running, failed].
      if (e.type === 105 && e.id !== 0 && (e.id === _buildId || e.id === _copyId) && e.fields !== undefined && e.fields.length >= 4) {
        if (e.id === _buildId)
          _built = e.fields[0];
        else
          _fetched = e.fields[0];
        // A fetch can pull in a path the announcement did not list, so the count stops at it.
        var now = Math.min(total, _built + _fetched);
        if (now !== done)
          done = now;
        if (e.fields[3] > 0)
          _failed = true;
      }
      break;
    case "msg":
      _message(e.level, _strip(e.msg));
      break;
    }
  }

  function _message(level, text) {
    if (level === 0 && /^error\b(?! \(ignored\))/.test(text)) {
      _failed = true;
      return;
    }
    // Nix announces what it builds, then what it fetches; an announcement after the last one's
    // activities started is the next realisation, and replaces it.
    var built = /^(?:this derivation|these (\d+) derivations) will be built/.exec(text);
    var fetched = built === null ? /^(?:this path|these (\d+) paths) will be fetched/.exec(text) : null;
    var m = built || fetched;
    if (m === null)
      return;
    if (_buildId !== 0 || _copyId !== 0)
      _resetRealisation();
    var n = m[1] !== undefined ? parseInt(m[1], 10) : 1;
    if (built !== null)
      _toBuild = n;
    else
      _toFetch = n;
    total = _toBuild + _toFetch;
    done = 0;
    _announced = true;
  }

  function _resetRealisation() {
    _toBuild = 0;
    _toFetch = 0;
    _buildId = 0;
    _copyId = 0;
    _built = 0;
    _fetched = 0;
    _announced = false;
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
    // Prints the live ones, and each live Nix process's parent as "parent <pid>" if that is
    // nixos-rebuild (a `nix build` run by hand is not waited on past its end). Field 4 of stat is
    // the parent; a Nix process's name has no spaces, so plain splitting finds it.
    var args = Object.keys(_pids).map(p => (_pids[p] === "parent" ? "p" : "n") + p);
    probe.command = ["sh", "-c", "for a; do p=${a#?}; [ -d /proc/$p ] || continue; echo $p; [ ${a%$p} = n ] && read -r _ _ _ pp _ < /proc/$p/stat && grep -qa nixos-rebuild /proc/$pp/cmdline 2>/dev/null && echo parent $pp; done", "sh"].concat(args);
    probe.running = true;
  }

  Process {
    id: probe

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.phase !== "running")
          return;
        var lines = text.trim() === "" ? [] : text.trim().split("\n");
        var parents = null;
        for (var i = 0; i < lines.length; i++) {
          var m = /^parent (\d+)$/.exec(lines[i]);
          if (m === null)
            continue;
          if (root._pids[m[1]] === undefined) {
            parents = parents || Object.assign({}, root._pids);
            parents[m[1]] = "parent";
          }
        }
        if (parents !== null)
          root._pids = parents;
        if (lines.length > 0)
          root._lastAlive = Date.now();
        else if (Date.now() - root._lastEvent >= root.quietMs)
          root._finish();
      }
    }
  }

  function _finish() {
    endedAt = Math.max(_lastEvent, _lastAlive);
    var failed = _failed || _openCount > 0;
    if (!failed && total > 0)
      done = total;
    _announced = false;
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
  Process {
    id: tail

    command: ["tail", "-n0", "-F", "--pid=" + Quickshell.processId, root.logPath]
    running: true

    stdout: SplitParser {
      onRead: line => root.read(line)
    }

    // Until the first run there is no file, which tail says once and waits for.
    stderr: SplitParser {}

    onExited: restart.start()
  }

  Timer {
    id: restart

    interval: 5000
    onTriggered: tail.running = true
  }
}
