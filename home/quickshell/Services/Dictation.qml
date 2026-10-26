pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Handy's recording overlay, read off the socket its shell-bridge patch serves (see
// pkgs/handy/shell-bridge.patch): one JSON event a line. A session runs listening -> working
// -> gone; the island's dictation pill draws it. Handy may start after the shell or restart,
// so the socket is retried while it is down, and a lost connection ends whatever was showing.
Singleton {
  id: root

  // "" with nothing running, "listening" while recording, "working" while it finishes.
  property string phase: ""

  // The microphone is delivering samples; until then the bars stay flat.
  property bool ready: false

  // When `ready` went up, in ms since the epoch: the pill's clock counts from here.
  property real readyAt: 0

  // "transcribing", or "polishing" while post-processing runs.
  property string workKind: "transcribing"

  // Live text: `committed` no longer changes, `tentative` may still be rewritten.
  property string committed: ""
  property string tentative: ""

  // Handy's 16 spectrum buckets, 0..1, smoothed as its own overlay smooths them.
  property var levels: zeroLevels()

  readonly property bool active: phase !== ""
  readonly property bool hasText: committed !== "" || tentative !== ""

  function zeroLevels() {
    var out = [];
    for (var i = 0; i < 16; i++)
      out.push(0);
    return out;
  }

  function reset() {
    phase = "";
    ready = false;
    readyAt = 0;
    workKind = "transcribing";
    committed = "";
    tentative = "";
    levels = zeroLevels();
  }

  function cancel() {
    cancelProc.running = true;
  }

  function handle(line) {
    var e;
    try {
      e = JSON.parse(line);
    } catch (err) {
      return;
    }
    switch (e.event) {
    case "state":
      if (e.state === "recording" || e.state === "streaming") {
        reset();
        phase = "listening";
      } else {
        phase = "working";
        workKind = e.state === "processing" ? "polishing" : "transcribing";
        levels = zeroLevels();
      }
      break;
    case "ready":
      ready = true;
      readyAt = Date.now();
      break;
    case "levels":
      if (phase !== "listening")
        break;
      var next = [];
      for (var i = 0; i < 16; i++)
        next.push(levels[i] * 0.7 + (e.levels[i] || 0) * 0.3);
      levels = next;
      break;
    case "text":
      committed = e.committed || "";
      tentative = e.tentative || "";
      break;
    case "working":
      phase = "working";
      workKind = e.kind === "polishing" ? "polishing" : "transcribing";
      levels = zeroLevels();
      break;
    case "hide":
      reset();
      break;
    }
  }

  Socket {
    id: socket

    path: Quickshell.env("XDG_RUNTIME_DIR") + "/handy/overlay.sock"
    connected: true
    onConnectedChanged: {
      if (connected) {
        retry.interval = 1000;
      } else {
        root.reset();
        retry.interval = 1000;
      }
    }

    parser: SplitParser {
      onRead: data => root.handle(data)
    }
  }

  // Each failed attempt logs a warning, so the retry backs off while Handy is away: quick
  // after a restart, then no more than twice a minute.
  Timer {
    id: retry

    interval: 1000
    repeat: true
    running: !socket.connected
    onTriggered: {
      socket.connected = true;
      interval = Math.min(interval * 2, 30000);
    }
  }

  Process {
    id: cancelProc

    command: ["handy", "--cancel"]
  }
}
