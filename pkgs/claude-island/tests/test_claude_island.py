"""Tests for claude-island: gating, payload shapes, window resolution and hook latency."""

import importlib.machinery
import importlib.util
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest

BIN = os.environ["CLAUDE_ISLAND_BIN"]
CLI_ENV = {"CLAUDE_CODE_ENTRYPOINT": "cli", "PATH": os.environ.get("PATH", "")}


def load(rundir, proc):
    os.environ.update(XDG_RUNTIME_DIR=rundir, CLAUDE_ISLAND_PROC=proc)
    os.environ.pop("CLAUDE_ISLAND_SOCKET", None)
    os.environ.pop("CLAUDE_ISLAND_STATE", None)
    loader = importlib.machinery.SourceFileLoader("claude_island", BIN)
    spec = importlib.util.spec_from_loader("claude_island", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def fake_proc(root, tree, tty="/dev/pts/7"):
    """tree: [(pid, ppid, comm)]; the process named claude reads from `tty`."""
    for pid, ppid, comm in tree:
        d = os.path.join(root, str(pid))
        os.makedirs(os.path.join(d, "fd"), exist_ok=True)
        with open(os.path.join(d, "stat"), "w") as f:
            f.write(f"{pid} ({comm}) S {ppid} 1 1 0 0\n")
        with open(os.path.join(d, "comm"), "w") as f:
            f.write(comm + "\n")
        with open(os.path.join(d, "cmdline"), "wb") as f:
            f.write(comm.encode() + b"\0")
        if comm in ("claude", ".claude-wrapped"):
            link = os.path.join(d, "fd", "0")
            if tty:
                os.symlink(tty, link)


class Listener:
    """The shell's socket: collects the JSON lines sent to it."""

    def __init__(self, path):
        self.lines = []
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(path)
        self.server.listen(8)
        self.server.settimeout(0.2)
        self.stop = False
        self.thread = threading.Thread(target=self.run)
        self.thread.start()

    def run(self):
        while not self.stop:
            try:
                conn, _ = self.server.accept()
            except (socket.timeout, OSError):
                continue
            with conn:
                data = b""
                while chunk := conn.recv(4096):
                    data += chunk
                self.lines += [json.loads(line) for line in data.splitlines() if line]

    def close(self):
        self.stop = True
        self.thread.join()
        self.server.close()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.run_dir = os.path.join(self.tmp.name, "run")
        self.proc = os.path.join(self.tmp.name, "proc")
        os.makedirs(self.run_dir)
        os.makedirs(self.proc)
        self.mod = load(self.run_dir, self.proc)
        fake_proc(self.proc, [(500, 1, "ghostty"), (510, 500, "fish"), (520, 510, "claude"), (530, 520, "sh")])
        self.mod.os.getppid = lambda: 530
        self.listener = Listener(self.mod.SOCKET)

    def tearDown(self):
        self.listener.close()
        self.tmp.cleanup()

    def fire(self, payload, env=None):
        self.mod.hook(json.dumps(payload).encode(), env or CLI_ENV)
        time.sleep(0.05)
        return self.listener.lines


class Gating(unittest.TestCase):
    def setUp(self):
        self.mod = load(tempfile.gettempdir(), "/proc")

    def test_only_interactive_cli(self):
        ok = self.mod.wanted_env
        self.assertTrue(ok({"CLAUDE_CODE_ENTRYPOINT": "cli"}))
        for entry in ("sdk-ts", "sdk-cli", "sdk-py", "claude-vscode", "claude-desktop", "local-agent", "mcp", ""):
            self.assertFalse(ok({"CLAUDE_CODE_ENTRYPOINT": entry}), entry)
        self.assertFalse(ok({}))

    def test_children_and_t3_refused(self):
        ok = self.mod.wanted_env
        base = {"CLAUDE_CODE_ENTRYPOINT": "cli"}
        self.assertFalse(ok({**base, "CLAUDE_CODE_CHILD_SESSION": "1"}))
        self.assertFalse(ok({**base, "CLAUDE_CODE_SESSION_ATTENDED": "0"}))
        self.assertFalse(ok({**base, "T3CODE_THREAD_ID": "x"}))
        self.assertFalse(ok({**base, "CLAUDE_ISLAND": "0"}))

    def test_helpers(self):
        self.assertEqual(self.mod.tool_detail("Bash", {"command": "nix build\n  .#x"}), "Bash(nix build .#x)")
        self.assertEqual(self.mod.tool_detail("Edit", {"file_path": "/a/b.nix", "old_string": "x"}), "Edit(/a/b.nix)")
        self.assertEqual(self.mod.tool_detail("Foo", {}), "Foo")
        self.assertEqual(self.mod.digest("## Done\n\n- built `x`\n- third"), "Done built x")

    def test_project_is_git_root(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "proj", ".git"))
            os.makedirs(os.path.join(d, "proj", "sub", "deep"))
            self.assertEqual(self.mod.project_of(os.path.join(d, "proj", "sub", "deep")), "proj")
            self.assertEqual(self.mod.project_of(os.path.join(d, "proj", "sub")), "proj")
        self.assertEqual(self.mod.project_of("/nonexistent/place/"), "place")


class Hook(Base):
    def test_permission_then_answered(self):
        pay = {"session_id": "s1", "cwd": "/nonexistent/nixos", "hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_input": {"command": "nix build .#x"}}
        lines = self.fire(pay)
        self.assertEqual(lines[0]["op"], "state")
        self.assertEqual(lines[0]["state"], "permission")
        self.assertEqual(lines[0]["detail"], "Bash(nix build .#x)")
        self.assertEqual(lines[0]["project"], "nixos")
        lines = self.fire({"session_id": "s1", "cwd": "/nonexistent/nixos", "hook_event_name": "PostToolUse", "tool_name": "Bash"})
        self.assertEqual(lines[-1]["op"], "clear")

    def test_post_tool_use_is_silent_without_a_question(self):
        self.assertEqual(self.fire({"session_id": "s2", "hook_event_name": "PostToolUse"}), [])

    def test_stop_prompt_end(self):
        self.fire({"session_id": "s3", "cwd": "/x/y", "hook_event_name": "Stop", "last_assistant_message": "All **done**.\nRan tests."})
        self.assertEqual(self.listener.lines[-1]["message"], "All done. Ran tests.")
        self.fire({"session_id": "s3", "cwd": "/x/y", "hook_event_name": "UserPromptSubmit", "prompt": "go"})
        self.assertEqual(self.listener.lines[-1]["op"], "clear")
        self.fire({"session_id": "s3", "cwd": "/x/y", "hook_event_name": "SessionEnd", "reason": "exit"})
        self.assertTrue(self.listener.lines[-1]["ended"])

    def test_notification_kinds(self):
        n = lambda kind, msg="m": {"session_id": "s4", "cwd": "/x/y", "hook_event_name": "Notification", "notification_type": kind, "message": msg}
        self.assertEqual(self.fire(n("idle_prompt")), [])
        self.assertEqual(self.fire(n("auth_success")), [])
        self.assertEqual(self.fire(n("permission_prompt", "Claude needs your permission to use Bash"))[-1]["state"], "permission")
        self.assertEqual(self.fire(n("elicitation_dialog", "Pick one"))[-1]["state"], "question")

    def test_refused_sessions_send_nothing(self):
        pay = {"session_id": "s5", "cwd": "/x", "hook_event_name": "Stop"}
        for env in ({**CLI_ENV, "CLAUDE_CODE_ENTRYPOINT": "sdk-ts"}, {**CLI_ENV, "T3CODE_THREAD_ID": "t"}, {**CLI_ENV, "CLAUDE_CODE_CHILD_SESSION": "1"}):
            self.assertEqual(self.fire(pay, env), [])

    def test_no_tty_sends_nothing(self):
        os.unlink(os.path.join(self.proc, "520", "fd", "0"))
        os.symlink("/dev/null", os.path.join(self.proc, "520", "fd", "0"))
        self.assertEqual(self.fire({"session_id": "s6", "cwd": "/x", "hook_event_name": "Stop"}), [])

    def test_no_claude_ancestor_sends_nothing(self):
        self.mod.os.getppid = lambda: 510
        self.assertEqual(self.fire({"session_id": "s7", "cwd": "/x", "hook_event_name": "Stop"}), [])

    def test_prompt_records_the_focused_terminal(self):
        self.mod.active_terminal = lambda: "0xabc"
        self.fire({"session_id": "s8", "cwd": "/x/y", "hook_event_name": "UserPromptSubmit"})
        state = self.mod.load_state("s8")
        self.assertEqual(state["window"], "0xabc")
        self.assertEqual(state["chain"][:3], [530, 520, 510])


def client(address, pid, title="fish", cls="com.mitchellh.ghostty", hist=1, mapped=True):
    return {"address": address, "pid": pid, "title": title, "class": cls, "focusHistoryID": hist, "mapped": mapped}


class Resolve(unittest.TestCase):
    def setUp(self):
        self.mod = load(tempfile.gettempdir(), "/proc")

    def test_single_window_per_process(self):
        clients = [client("0x1", 500), client("0x2", 600), client("0x3", 77, cls="firefox")]
        self.assertEqual(self.mod.resolve_window({"chain": [530, 520, 510, 500]}, clients), ("0x1", "process"))

    def test_one_process_many_windows_uses_the_recorded_focus(self):
        clients = [client("0x1", 500), client("0x2", 500), client("0x3", 500)]
        state = {"chain": [530, 500], "window": "0x2", "project": "nixos"}
        self.assertEqual(self.mod.resolve_window(state, clients), ("0x2", "focus"))

    def test_multiplexer_leaves_no_process_link(self):
        clients = [client("0x1", 500), client("0x2", 500)]
        state = {"chain": [530, 520, 1000], "window": "0x1", "project": "nixos"}
        self.assertEqual(self.mod.resolve_window(state, clients), ("0x1", "focus"))

    def test_recorded_window_gone_falls_back_to_title_then_guess(self):
        clients = [client("0x1", 500, title="nixos - claude"), client("0x2", 500, title="other", hist=0)]
        state = {"chain": [], "window": "0x9", "project": "nixos", "cwd": "/home/ryan/nixos"}
        self.assertEqual(self.mod.resolve_window(state, clients), ("0x1", "title"))
        state["project"] = state["cwd"] = ""
        self.assertEqual(self.mod.resolve_window(state, clients), ("0x2", "guess"))

    def test_no_terminal_no_window(self):
        self.assertEqual(self.mod.resolve_window({"chain": [1]}, [client("0x1", 5, cls="firefox")]), ("", "none"))
        self.assertEqual(self.mod.resolve_window({"chain": [500]}, [client("0x1", 500, mapped=False)]), ("", "none"))


class Cli(unittest.TestCase):
    def run_hook(self, env, payload=b'{"session_id":"z","hook_event_name":"Stop","cwd":"/x"}'):
        t0 = time.monotonic()
        p = subprocess.run([BIN, "hook"], input=payload, capture_output=True, env=env, timeout=10)
        return p, time.monotonic() - t0

    def test_silent_exit_zero_without_the_shell(self):
        with tempfile.TemporaryDirectory() as d:
            env = {**CLI_ENV, "XDG_RUNTIME_DIR": d}
            p, took = self.run_hook(env)
            self.assertEqual((p.returncode, p.stdout, p.stderr), (0, b"", b""))
            self.assertLess(took, 0.5)

    def test_silent_exit_zero_for_sdk_sessions_and_garbage(self):
        with tempfile.TemporaryDirectory() as d:
            open(os.path.join(d, "quickshell-island.sock"), "w").close()  # a dead socket file
            for env, payload in (
                ({"XDG_RUNTIME_DIR": d, "CLAUDE_CODE_ENTRYPOINT": "sdk-ts"}, b"{}"),
                ({"XDG_RUNTIME_DIR": d, "CLAUDE_CODE_ENTRYPOINT": "cli"}, b"not json"),
                ({"XDG_RUNTIME_DIR": d, "CLAUDE_CODE_ENTRYPOINT": "cli"}, b""),
            ):
                p, took = self.run_hook(env, payload)
                self.assertEqual((p.returncode, p.stdout, p.stderr), (0, b"", b""))
                self.assertLess(took, 0.5)

    def test_hook_is_fast(self):
        with tempfile.TemporaryDirectory() as d:
            ls = Listener(os.path.join(d, "quickshell-island.sock"))
            try:
                env = {**CLI_ENV, "XDG_RUNTIME_DIR": d}
                times = sorted(self.run_hook(env)[1] for _ in range(5))
                self.assertLess(times[2], 0.15)  # no claude ancestor here: the gate stops it
            finally:
                ls.close()


if __name__ == "__main__":
    unittest.main()
