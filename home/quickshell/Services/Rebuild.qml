pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

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
// - "these N derivations will be built" is the total. Nix's own count (the progress of the
//   `builds` activity, type 104, field 1) is not: it counts evaluation-time builds and swings
//   up and down, so only its `done` (field 0, a result of type 105) is used, of the activity
//   started after that message. Until the message there is no total, which is the pill's
//   evaluating state;
// - a message of level 0 that starts "error" (not "error (ignored)") and a build that failed
//   (field 3) mean failure;
// - the run is over when none of its processes is alive and the log has been quiet a moment (the
//   next nix process of the same rebuild starts within that). It failed if an error was seen, or
//   an activity was still open (a process that ended without a result: killed, or Ctrl-C), else
//   it is done. "Done" is the end of the last Nix process, so for a switch it is the build and
//   the new generation being set, not the activation that follows; see the pill.
Singleton {
  id: root

  // The alias passes the same path.
  readonly property string logPath: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/rebuild.jsonl"

  // "" when there is none; else building, done or failed. Only the latest run is kept.
  property string phase: ""
  property real startedAt: 0
  property real endedAt: 0

  // Derivations finished, of `total`; 0 while the total is not known.
  property int done: 0
  property int total: 0

  // The user has dismissed the finished or failed run.
  property bool dismissed: false

  readonly property bool running: phase === "building"
  readonly property bool shown: phase !== "" && !dismissed
  readonly property real fraction: total > 0 ? Theme.clamp01(done / total) : 0

  // How long the log must have been quiet, with no process alive, to call a run over.
  property int quietMs: 2500

  function dismiss() {
    dismissed = true;
  }

  // ---- reading ----

  property var _pids: ({})
  property var _open: ({})
  property int _openCount: 0
  // Activity ids carry the pid in their top half, so they do not fit an int.
  property real _buildId: 0
  // A realisation has been announced, so the next builds activity is its.
  property bool _announced: false
  property real _lastEvent: 0
  property bool _failed: false

  function _strip(text) {
    return String(text).replace(/\u001b\[[0-9;]*m/g, "");
  }

  function _begin() {
    phase = "building";
    startedAt = Date.now();
    endedAt = 0;
    done = 0;
    total = 0;
    dismissed = false;
    _pids = {};
    _open = {};
    _openCount = 0;
    _buildId = 0;
    _announced = false;
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
    if (phase !== "building")
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
      // The builds of the realisation announced above, not the ones evaluation made.
      if (e.type === 104 && _buildId === 0 && _announced)
        _buildId = e.id;
      break;
    case "stop":
      if (_open[e.id] !== undefined) {
        delete _open[e.id];
        _openCount--;
      }
      break;
    case "result":
      // Progress of the builds: [done, expected, running, failed].
      if (e.type === 105 && e.id === _buildId && _buildId !== 0 && e.fields !== undefined && e.fields.length >= 4) {
        if (e.fields[0] !== done)
          done = e.fields[0];
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
    var m = /^(?:this derivation|these (\d+) derivations) will be built/.exec(text);
    if (m !== null) {
      total = m[1] !== undefined ? parseInt(m[1], 10) : 1;
      done = 0;
      _buildId = 0;
      _announced = true;
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
    probe.command = ["sh", "-c", "for p; do [ -d /proc/$p ] && echo $p; done", "sh"].concat(Object.keys(_pids));
    probe.running = true;
  }

  Process {
    id: probe

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.phase === "building" && text.trim() === "" && Date.now() - root._lastEvent >= root.quietMs)
          root._finish();
      }
    }
  }

  function _finish() {
    endedAt = _lastEvent;
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
