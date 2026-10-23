pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Launcher
import "../Commons/Fuzzy.js" as Fuzzy

// A chat with Claude in the launcher, an Omnibox provider with its own view. Every unscoped
// query gets an "Ask Claude" row at the foot of the list (Tab jumps straight to it), and an
// "AI Chat" row opens an empty chat. Answers come from the Claude Code CLI on Ryan's
// subscription login: one `claude -p` per turn, streamed as JSON lines, later turns
// resuming the session the first one opened. Sessions are kept on disk, so recent chats can
// be listed and picked up again.
Singleton {
  id: root

  property string query: ""
  property bool scoped: false

  readonly property string section: "Ask Claude"
  readonly property string prefix: "?"
  readonly property string scopeGlyph: Icons.assistant
  readonly property string hint: "Ask Claude anything…"

  readonly property Component view: Component {
    ChatView {}
  }

  // The CLI by name, so the shell's PATH decides; and the alias each turn asks for.
  property string cli: "claude"
  property string model: "sonnet"
  readonly property var models: ["sonnet", "opus", "haiku"]

  // A neutral working directory: the repo's CLAUDE.md and project settings are never seen.
  readonly property string workDir: Paths.home + "/.cache/quickshell/claude"

  readonly property string systemPrompt: "You are answering inside a desktop launcher on Ryan's NixOS/Hyprland laptop. Be concise; use Markdown sparingly. No tools are available. Today is " + Qt.formatDate(new Date(), "dddd d MMMM yyyy") + "."

  // The open conversation. Turns are { role: "user" | "assistant", text, error, detail };
  // `error` is "" or a kind: "missing", "auth", "limit", "failed", "stopped".
  property ListModel turns: ListModel {}
  property string sessionId: ""
  property bool streaming: false
  // Set by the first event of a turn; the dots show until text arrives.
  property bool waiting: false
  // The model the CLI resolved the alias to ("claude-sonnet-5-5"), for the header.
  property string resolvedModel: ""

  // { id, title, at, model, turns: [{ role, text, error, detail }] }, newest first.
  property var recent: []
  readonly property int recentLimit: 8

  // ---- provider ----------------------------------------------------------------------

  readonly property string asked: query.trim()

  readonly property var entryWords: ["ai chat", "ask claude", "claude", "chat"]

  function entryRow(score, matches) {
    return {
      id: "claude:chat",
      kind: "chat",
      name: "AI Chat",
      desc: "Ask Claude · new conversation",
      icon: "",
      glyph: Icons.assistant,
      swatch: "",
      score: score,
      matches: matches
    };
  }

  // Low enough to sit under every real match, so it is only first when nothing else is.
  readonly property int askScore: 1
  readonly property int entryScore: 62

  readonly property var results: {
    var q = root.asked;
    if (q.length === 0)
      return [];
    var out = [];
    if (!root.scoped) {
      var lower = q.toLowerCase();
      for (var i = 0; i < root.entryWords.length; i++) {
        var w = root.entryWords[i];
        if (w.startsWith(lower) || w.indexOf(" " + lower) >= 0) {
          var fz = Fuzzy.match(lower, "AI Chat");
          out.push(root.entryRow(root.entryScore, fz && lower.length <= 2 && "ai chat".startsWith(lower) ? fz.positions : []));
          break;
        }
      }
      if (q.length < 2)
        return out;
    }
    out.push({
      id: "claude:ask",
      kind: "ask",
      text: q,
      name: "Ask Claude “" + q + "”",
      desc: "",
      icon: "",
      glyph: Icons.assistant,
      swatch: "",
      score: root.scoped ? 90 : root.askScore,
      matches: []
    });
    return out;
  }

  readonly property var emptyResults: {
    // The plain empty launcher stays the apps; chats are a typed "ai" or Tab away.
    if (!root.scoped)
      return [];
    var out = [root.entryRow(0, [])];
    out[0].name = "New chat";
    out[0].desc = "";
    for (var i = 0; i < root.recent.length; i++) {
      var c = root.recent[i];
      out.push({
        id: "claude:session:" + c.id,
        kind: "resume",
        session: c.id,
        name: c.title,
        desc: root.ago(c.at) + " · " + c.turns.length + " messages",
        icon: "",
        glyph: Icons.assistant,
        swatch: "",
        score: 0,
        matches: []
      });
    }
    return out;
  }

  function activate(row, modifiers) {
    if (row.kind === "ask")
      root.ask(row.text);
    else if (row.kind === "resume")
      root.resume(row.session);
    else {
      root.newChat();
      Omnibox.openView(root);
    }
    return true;
  }

  // Tab on any unscoped query, from Omnibox.tab.
  function ask(text) {
    root.newChat();
    Omnibox.openView(root);
    root.send(text);
  }

  function ago(ms) {
    var m = Math.round((Date.now() - ms) / 60000);
    if (m < 1)
      return "Just now";
    if (m < 60)
      return m + " min ago";
    if (m < 60 * 24)
      return Math.round(m / 60) + " h ago";
    return Qt.formatDate(new Date(ms), "d MMM");
  }

  // ---- conversation ------------------------------------------------------------------

  function newChat() {
    root.stop();
    turns.clear();
    root.sessionId = "";
  }

  function resume(id) {
    for (var i = 0; i < root.recent.length; i++) {
      var c = root.recent[i];
      if (c.id !== id)
        continue;
      root.newChat();
      for (var j = 0; j < c.turns.length; j++)
        turns.append(root.turn(c.turns[j].role, c.turns[j].text, c.turns[j].error || "", c.turns[j].detail || ""));
      root.sessionId = c.id;
      Omnibox.openView(root);
      return;
    }
  }

  function turn(role, text, error, detail) {
    return {
      role: role,
      text: text,
      error: error,
      detail: detail
    };
  }

  function cycleModel() {
    root.model = root.models[(root.models.indexOf(root.model) + 1) % root.models.length];
    root.resolvedModel = "";
  }

  // The last reply with any text, for the copy key.
  function lastReply() {
    for (var i = turns.count - 1; i >= 0; i--) {
      var t = turns.get(i);
      if (t.role === "assistant" && t.text.length > 0)
        return t.text;
    }
    return "";
  }

  function send(text) {
    var q = String(text).trim();
    if (q.length === 0 || root.streaming)
      return false;
    turns.append(root.turn("user", q, "", ""));
    turns.append(root.turn("assistant", "", "", ""));
    root.pending = "";
    root.sawResult = false;
    root.stopping = false;
    root.blocks = 0;
    // The prompt is one argv element, never parsed by a shell. `sh` only checks the CLI is
    // there: 127 otherwise, which reads better than a failed spawn.
    var args = ["sh", "-c", 'command -v "$0" >/dev/null 2>&1 || exit 127; exec "$0" "$@"', root.cli, "-p", q, "--output-format", "stream-json", "--verbose", "--include-partial-messages", "--model", root.model, "--strict-mcp-config", "--tools", "", "--safe-mode", "--system-prompt", root.systemPrompt];
    if (root.sessionId)
      args.push("--resume", root.sessionId);
    root.streaming = true;
    root.waiting = true;
    root.proc = runner.createObject(root, {
      command: args
    });
    root.proc.running = true;
    return true;
  }

  // The process of the turn in flight. A stopped or abandoned one is cut loose: its late
  // events and exit go nowhere, so a new turn never races the old one's exit.
  property var proc: null

  function stop() {
    if (!root.proc)
      return;
    var p = root.proc;
    root.stopping = true;
    root.finish(0);
    p.running = false;
  }

  // Deltas arrive a few words at a time; they are folded into the last turn on a short beat
  // so a long reply re-lays its Markdown a few dozen times, not once per token.
  property string pending: ""
  property bool sawResult: false
  property bool stopping: false
  property int blocks: 0

  function flush() {
    if (root.pending.length === 0 || turns.count === 0)
      return;
    var last = turns.count - 1;
    turns.setProperty(last, "text", turns.get(last).text + root.pending);
    root.pending = "";
    root.waiting = false;
  }

  function fail(kind, detail) {
    root.flush();
    if (turns.count === 0)
      return;
    var last = turns.count - 1;
    turns.setProperty(last, "error", kind);
    turns.setProperty(last, "detail", detail || "");
    root.waiting = false;
  }

  function onEvent(ev) {
    switch (ev.type) {
    case "system":
      if (ev.subtype === "init") {
        if (ev.session_id)
          root.sessionId = ev.session_id;
        if (ev.model)
          root.resolvedModel = ev.model;
      }
      break;
    case "stream_event":
      var e = ev.event || {};
      if (e.type === "content_block_start" && e.content_block && e.content_block.type === "text") {
        // A second text block in one reply is a new paragraph.
        if (root.blocks++ > 0)
          root.pending += "\n\n";
      } else if (e.type === "content_block_delta" && e.delta && e.delta.type === "text_delta") {
        root.pending += e.delta.text;
        if (!flushBeat.running)
          flushBeat.start();
      }
      break;
    case "assistant":
      // Errors the CLI answers for itself (signed out, limits) come as a whole message.
      if (ev.error)
        root.fail(root.errorKind(ev.error), root.messageText(ev.message));
      break;
    case "rate_limit_event":
      var info = ev.rate_limit_info || {};
      if (info.status === "rejected")
        root.fail("limit", info.resetsAt ? "Resets at " + Qt.formatTime(new Date(info.resetsAt * 1000), "HH:mm") + "." : "");
      break;
    case "result":
      root.sawResult = true;
      if (ev.session_id)
        root.sessionId = ev.session_id;
      root.flush();
      var last = turns.count - 1;
      if (ev.is_error) {
        // A failed run carries `errors` and no `result` ("No conversation found…").
        var said = String(ev.result || (ev.errors || []).join("\n"));
        if (last >= 0 && turns.get(last).error === "")
          root.fail(root.errorKind(said), said);
      } else if (last >= 0 && turns.get(last).text.length === 0 && ev.result) {
        turns.setProperty(last, "text", String(ev.result));
      }
      break;
    }
  }

  function messageText(message) {
    var parts = (message && message.content) || [];
    var out = [];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].type === "text")
        out.push(parts[i].text);
    }
    return out.join("\n");
  }

  function errorKind(code) {
    var s = String(code).toLowerCase();
    if (s.indexOf("auth") >= 0 || s.indexOf("not logged in") >= 0 || s.indexOf("/login") >= 0)
      return "auth";
    if (s.indexOf("rate") >= 0 || s.indexOf("limit") >= 0 || s.indexOf("overload") >= 0)
      return "limit";
    return "failed";
  }

  // The turn is over: its process exited, or was stopped and cut loose.
  function finish(code, stderr) {
    flushBeat.stop();
    root.flush();
    var last = turns.count - 1;
    if (last >= 0 && turns.get(last).error === "") {
      if (root.stopping)
        root.fail("stopped", "");
      else if (code === 127)
        root.fail("missing", "");
      else if (!root.sawResult)
        root.fail("failed", String(stderr || "").trim().split("\n").slice(-3).join("\n") || "Claude Code exited with status " + code + ".");
    }
    root.proc = null;
    root.streaming = false;
    root.waiting = false;
    root.remember();
  }

  // ---- recent chats ------------------------------------------------------------------

  // Only a chat Claude answered at least once is worth going back to.
  function remember() {
    if (!root.sessionId || root.lastReply().length === 0)
      return;
    var saved = [];
    for (var i = 0; i < turns.count; i++) {
      var t = turns.get(i);
      saved.push(root.turn(t.role, t.text, t.error, t.detail));
    }
    var chat = {
      id: root.sessionId,
      title: saved[0].text.split("\n")[0].substr(0, 80),
      at: Date.now(),
      model: root.model,
      turns: saved
    };
    var next = [chat];
    for (var j = 0; j < root.recent.length && next.length < root.recentLimit; j++) {
      if (root.recent[j].id !== chat.id)
        next.push(root.recent[j]);
    }
    root.recent = next;
    store.setText(JSON.stringify(next));
  }

  FileView {
    id: store

    path: Paths.stateDir + "/claude-chats.json"
    printErrors: false

    onLoaded: {
      try {
        root.recent = JSON.parse(store.text()) || [];
      } catch (e) {
        root.recent = [];
      }
    }
  }

  Timer {
    id: flushBeat

    interval: 40
    onTriggered: root.flush()
  }

  // The cwd has to exist before the first turn's process can start in it.
  Process {
    command: ["mkdir", "-p", root.workDir]
    running: true
  }

  Component {
    id: runner

    Process {
      id: run

      property string stderrTail: ""

      workingDirectory: root.workDir
      // Telemetry and update checks cost ~200 ms before the first event, and hold the
      // process open for ~600 ms after the reply.
      environment: ({
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1"
        })

      stdout: SplitParser {
        onRead: function (line) {
          if (root.proc !== run)
            return;
          var ev;
          try {
            ev = JSON.parse(line);
          } catch (e) {
            return;
          }
          root.onEvent(ev);
        }
      }

      stderr: SplitParser {
        onRead: function (line) {
          run.stderrTail = (run.stderrTail + "\n" + line).slice(-600);
        }
      }

      onExited: function (code) {
        if (root.proc === run)
          root.finish(code, run.stderrTail);
        run.destroy();
      }
    }
  }
}
