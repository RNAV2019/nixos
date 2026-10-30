pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// The system rebuild that `rebuild` (pkgs/rebuild) is running, as it reports over
// Services/IslandBridge.qml: evaluating, building n of m derivations, activating, then done or
// failed. Only the latest run is kept. Its log and the diff against the running system are
// files the program saved; the card opens them in a terminal.
Singleton {
  id: root

  // "" when there is none; else evaluating, building, activating, done or failed.
  property string phase: ""
  property string runId: ""
  property string mode: "switch"
  property string host: ""
  property real startedAt: 0
  property real endedAt: 0

  property int done: 0
  property int total: 0
  // "derivations" or "paths".
  property string unit: "derivations"
  property string current: ""
  // The latest line of the activation, which says which units are restarting.
  property string detail: ""

  property string error: ""
  property string summary: ""
  property int changed: 0
  property int generation: 0
  property string logFile: ""
  property string diffFile: ""

  // Where a failure happened, for its caption ("Building · 1:12").
  property string stage: ""

  // The user has dismissed the finished or failed run, or it has stood long enough.
  property bool dismissed: false

  readonly property bool running: phase === "evaluating" || phase === "building" || phase === "activating"
  readonly property bool shown: phase !== "" && !dismissed
  readonly property real fraction: phase === "building" && total > 0 ? Theme.clamp01(done / total) : phase === "activating" || phase === "done" ? 1 : 0

  property real now: Date.now()
  readonly property real elapsed: Math.max(0, (running ? now : endedAt) - startedAt)

  readonly property var phaseTitles: ({
      evaluating: "Evaluating",
      building: "Building",
      activating: "Activating"
    })

  // What a finished run is called: the mode says whether anything was switched to.
  readonly property string doneTitle: ({
      switch: "Switched",
      boot: "Ready on next boot",
      test: "Activated",
      build: "Built",
      dry: "Dry run"
    })[mode] || "Done"

  // Cues for the moments: a run finished (not a dry run), or failed.
  signal finished
  signal failed

  function dismiss() {
    dismissed = true;
  }

  // Show the saved log (from its end, where a failure is) or the diff in a terminal.
  function showLog() {
    if (logFile !== "")
      viewer.exec(["ghostty", "-e", "less", "-R", "+G", logFile]);
  }

  function showDiff() {
    if (diffFile !== "")
      viewer.exec(["ghostty", "-e", "less", "-R", diffFile]);
  }

  function handle(msg) {
    if (msg.phase === "cancelled") {
      if (msg.id === runId)
        phase = "";
      return;
    }
    if (msg.id !== runId) {
      runId = msg.id;
      done = 0;
      total = 0;
      current = "";
      detail = "";
      error = "";
      summary = "";
      changed = 0;
      generation = 0;
      diffFile = "";
      stage = "";
      dismissed = false;
      endedAt = 0;
    }
    var before = phase;
    mode = msg.mode || "switch";
    host = msg.host || "";
    startedAt = msg.started || startedAt;
    logFile = msg.log || logFile;
    diffFile = msg.diff || diffFile;
    if (msg.total !== undefined) {
      done = msg.done;
      total = msg.total;
      unit = msg.unit || "derivations";
    }
    if (msg.current !== undefined)
      current = msg.current;
    if (msg.detail !== undefined)
      detail = msg.detail;
    if (msg.phase === "failed") {
      stage = before;
      error = msg.error || "The rebuild failed";
    }
    if (msg.phase === "done") {
      summary = msg.summary || "";
      changed = msg.changed || 0;
      generation = msg.generation || 0;
    }
    if (msg.ended)
      endedAt = msg.ended;
    phase = msg.phase;
    now = Date.now();
    if (before !== phase && phase === "done" && mode !== "dry")
      finished();
    if (before !== phase && phase === "failed")
      failed();
  }

  Connections {
    target: IslandBridge

    function onReceived(msg) {
      if (msg.src === "rebuild" && msg.id)
        root.handle(msg);
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.running
    onTriggered: root.now = Date.now()
  }

  // A finished run's satellite stands for a few minutes; a failed one until dismissed.
  Timer {
    interval: 300000
    running: root.phase === "done" && !root.dismissed
    onTriggered: root.dismissed = true
  }

  Command {
    id: viewer

    label: "rebuild viewer"
  }
}
