pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons

// Interactive Claude Code sessions that are waiting for the user, as Claude Code's hooks report
// them (pkgs/claude-island, registered in home/claude.nix) over Services/IslandBridge.qml. A
// session is here from the moment it asks for permission, asks a question or finishes its turn
// until the user answers (the hook says "clear"), dismisses it, or it ends.
//
//   state  "permission", "question" or "finished"
//   detail the tool and its argument for a permission ("Bash(nix build .#x)"), else the message
//   since  when it began to wait, ms
//
// Opening one raises its terminal through `claude-island focus`, which knows the process tree and
// the window it last saw the user prompt from; see pkgs/claude-island for how far that can be trusted.
Singleton {
  id: root

  // id -> session, for sessions waiting and not dismissed; `list` is the same, oldest first.
  property var sessions: ({})
  readonly property var list: Object.keys(sessions).map(k => sessions[k]).sort((a, b) => a.since - b.since)
  readonly property int count: list.length

  // A session started waiting (or changed what it waits for): the moment's cue.
  signal needsYou(var session)

  // The program: overridable so a test can stand in for it.
  readonly property string program: Quickshell.env("QUICKSHELL_CLAUDE_ISLAND") || "claude-island"

  // The focused window's address as Hyprland writes it, "" where there is none.
  readonly property string focusedWindow: {
    var top = Hyprland.activeToplevel;
    return top && top.address ? (String(top.address).startsWith("0x") ? top.address : "0x" + top.address) : "";
  }

  // A moment is pointless for a session whose terminal the user is looking at.
  function watched(session) {
    return session.window !== "" && session.window === focusedWindow;
  }

  function put(session) {
    var next = Object.assign({}, sessions);
    next[session.id] = session;
    sessions = next;
  }

  function drop(id) {
    if (sessions[id] === undefined)
      return;
    var next = Object.assign({}, sessions);
    delete next[id];
    sessions = next;
  }

  function handle(msg) {
    // Ids reach a shell command in the liveness probe: only Claude Code's own kind pass.
    if (!msg.session || !/^[A-Za-z0-9_.-]+$/.test(msg.session))
      return;
    if (msg.op === "clear") {
      drop(msg.session);
      return;
    }
    if (msg.op !== "state")
      return;
    var old = sessions[msg.session];
    var detail = msg.detail || "";
    var session = {
      id: msg.session,
      project: msg.project || "Claude Code",
      cwd: msg.cwd || "",
      pid: msg.pid || 0,
      window: msg.window || "",
      state: msg.state,
      // The permission hook carries the command and the Notification a sentence; keep the command.
      detail: detail !== "" ? detail : (old && old.state === msg.state && old.detail !== "" ? old.detail : (msg.message || "")),
      message: msg.message || "",
      since: msg.at || Date.now()
    };
    if (old && old.state === msg.state) {
      session.since = old.since;
      put(session);
      return;
    }
    if (session.state === "finished" && watched(session))
      return;
    put(session);
    needsYou(session);
  }

  // Waiting but not wanted any more (an Open or Dismiss that the user has answered by hand).
  function dismiss(id) {
    drop(id);
  }

  function open(id) {
    focusCommand.exec([program, "focus", id]);
  }

  Connections {
    target: IslandBridge

    function onReceived(msg) {
      if (msg.src === "claude")
        root.handle(msg);
    }
  }

  Command {
    id: focusCommand

    label: "Claude Code focus"
  }

  // A session killed without a word never says "clear": drop those whose process is gone.
  Process {
    id: probe

    stdout: StdioCollector {
      onStreamFinished: text.split("\n").filter(l => l !== "").forEach(id => root.drop(id))
    }
  }

  Timer {
    interval: 20000
    repeat: true
    running: root.count > 0
    onTriggered: {
      var checks = root.list.filter(s => s.pid > 0).map(s => "[ -d /proc/" + s.pid + " ] || echo " + s.id);
      if (checks.length > 0 && !probe.running) {
        probe.command = ["sh", "-c", checks.join("; ")];
        probe.running = true;
      }
    }
  }
}
