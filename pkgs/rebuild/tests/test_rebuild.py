"""Tests for rebuild: the log parser, the diff summary, and whole runs against stub tools."""

import importlib.machinery
import importlib.util
import json
import os
import socket
import stat
import subprocess
import tempfile
import threading
import time
import unittest

BIN = os.environ["REBUILD_BIN"]
FIX = os.environ["FIXTURES"]


def slurp(path):
    with open(path) as f:
        return f.read()


def load():
    loader = importlib.machinery.SourceFileLoader("rebuild_mod", BIN)
    spec = importlib.util.spec_from_loader("rebuild_mod", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def feed_file(name):
    mod = load()
    progress = mod.Progress()
    changes = []
    with open(os.path.join(FIX, name)) as f:
        for line in f:
            if progress.feed(line):
                changes.append(dict(progress.snapshot(), phase=progress.phase))
    return progress, changes


class Parser(unittest.TestCase):
    def test_successful_build(self):
        progress, changes = feed_file("ok.log")
        self.assertEqual(progress.phase, "building")
        self.assertEqual((progress.done, progress.total, progress.kind), (4, 4, "derivations"))
        self.assertEqual(progress.current, "rb-test-d")
        self.assertEqual(progress.error, "")
        self.assertIn("rb-test-a> building a", "\n".join(progress.text))
        # n/m only ever grows towards the total, and the first report is a build starting.
        done = [c["done"] for c in changes]
        self.assertEqual(done, sorted(done))
        self.assertEqual(changes[0]["total"], 4)
        self.assertEqual(changes[0]["phase"], "building")

    def test_failed_build_names_the_builders_last_line(self):
        progress, _ = feed_file("fail.log")
        self.assertEqual(progress.error, "make: *** [Makefile:12: all] Error 2")
        self.assertEqual(progress.failure(), "make: *** [Makefile:12: all] Error 2")

    def test_evaluation_alone_changes_nothing(self):
        mod = load()
        progress = mod.Progress()
        self.assertFalse(progress.feed('@nix {"action":"msg","level":4,"msg":"evaluating file \'x.nix\'"}'))
        self.assertFalse(progress.feed("warning: Git tree is dirty"))
        self.assertEqual(progress.phase, "evaluating")

    def test_substitution_counts_as_building(self):
        mod = load()
        progress = mod.Progress()
        start = {"action": "start", "id": 5, "type": 103, "fields": [], "text": "", "level": 0, "parent": 0}
        progress.feed("@nix " + json.dumps(start))
        progress.feed("@nix " + json.dumps({"action": "result", "id": 5, "type": 105, "fields": [3, 40, 1, 0]}))
        self.assertEqual((progress.done, progress.total, progress.kind), (3, 40, "paths"))

    def test_diff_summary(self):
        mod = load()
        with open(os.path.join(FIX, "dix.txt")) as f:
            count, names = mod.summarise_diff(f.read())
        self.assertEqual(count, 6)
        self.assertEqual(names, "alejandra 4.0.0 → 4.1.0, bash-interactive 5.3p15 → 5.3p20, firefox, ada, +2 more")

    def test_drv_name(self):
        mod = load()
        self.assertEqual(mod.drv_name("/nix/store/" + "a" * 32 + "-firefox-141.0.drv"), "firefox-141.0")


class Island:
    def __init__(self, path):
        self.lines = []
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(path)
        self.server.listen(16)
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
                while chunk := conn.recv(65536):
                    data += chunk
                self.lines += [json.loads(l) for l in data.splitlines() if l]

    def close(self):
        self.stop = True
        self.thread.join()
        self.server.close()


STUBS = {
    # Replays a fixture on stderr, the way nix does, and prints the out path.
    "nix": """#!/bin/sh
echo "$@" >> "$STUB_DIR/nix-args"
case "$*" in *--dry-run*) ;; *) echo /nix/store/00000000000000000000000000000000-nixos-system-test ;; esac
cat "$STUB_DIR/nix-log" >&2
exit "$(cat "$STUB_DIR/nix-exit")"
""",
    "nom": """#!/bin/sh
cat > "$STUB_DIR/nom-in"
""",
    "dix": """#!/bin/sh
cat "$FIXTURES/dix.txt"
""",
    "sudo": """#!/bin/sh
echo "sudo $*" >> "$STUB_DIR/calls"
[ "$1" = "-v" ] && exit "$(cat "$STUB_DIR/sudo-exit")"
exit 0
""",
    "nixos-rebuild": """#!/bin/sh
echo "nixos-rebuild $*" >> "$STUB_DIR/calls"
echo "restarting the following units: sshd.service"
[ -f "$STUB_DIR/activate-fail" ] && { echo "Failed to restart sshd.service" >&2; exit 4; }
exit 0
""",
}


class Run(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.tmp.name
        self.stubs = os.path.join(t, "stubs")
        os.makedirs(self.stubs)
        for name, body in STUBS.items():
            path = os.path.join(self.stubs, name)
            with open(path, "w") as f:
                f.write(body)
            os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)
        self.set("nix-exit", "0")
        self.set("sudo-exit", "0")
        self.run_dir = os.path.join(t, "run")
        os.makedirs(self.run_dir)
        self.sock = os.path.join(self.run_dir, "quickshell-island.sock")
        self.env = {
            "PATH": self.stubs + ":" + os.environ["PATH"],
            "STUB_DIR": self.stubs,
            "FIXTURES": FIX,
            "XDG_RUNTIME_DIR": self.run_dir,
            "XDG_STATE_HOME": os.path.join(t, "state"),
            "REBUILD_HOST": "testhost",
            "REBUILD_CURRENT": t,
            "REBUILD_FLAKE": "/repo",
            "HOME": t,
        }

    def tearDown(self):
        self.tmp.cleanup()

    def set(self, name, text):
        with open(os.path.join(self.stubs, name), "w") as f:
            f.write(text)

    def log(self, name):
        with open(os.path.join(FIX, name)) as f:
            self.set("nix-log", f.read())

    def rebuild(self, *args, island=True):
        listener = Island(self.sock) if island else None
        try:
            p = subprocess.run([BIN, *args], capture_output=True, text=True, env=self.env, timeout=60)
            time.sleep(0.1)
        finally:
            if listener:
                listener.close()
        return p, listener.lines if listener else []

    def calls(self):
        try:
            with open(os.path.join(self.stubs, "calls")) as f:
                return f.read().splitlines()
        except OSError:
            return []

    def test_switch(self):
        self.log("ok.log")
        p, lines = self.rebuild()
        self.assertEqual(p.returncode, 0, p.stderr)
        phases = [l["phase"] for l in lines]
        self.assertEqual(phases[0], "evaluating")
        self.assertIn("building", phases)
        self.assertLess(phases.index("building"), phases.index("activating"))
        self.assertEqual(phases[-1], "done")
        last = lines[-1]
        self.assertEqual((last["mode"], last["host"], last["changed"]), ("switch", "testhost", 6))
        self.assertIn("alejandra 4.0.0 → 4.1.0", last["summary"])
        self.assertTrue(os.path.exists(last["log"]) and os.path.exists(last["diff"]))
        self.assertIn("rb-test-a> building a", slurp(last["log"]))
        building = [l for l in lines if l["phase"] == "building"]
        self.assertEqual(building[-1]["total"], 4)
        self.assertEqual(building[-1]["current"], "rb-test-d")
        self.assertEqual(self.calls()[0], "sudo -v")
        self.assertIn("nixos-rebuild switch --store-path /nix/store/00000000000000000000000000000000-nixos-system-test --elevate sudo", self.calls()[1])
        self.assertIn("restarting the following units", p.stdout)

    def test_progress_is_rate_limited(self):
        self.log("ok.log")
        _, lines = self.rebuild()
        # The fixture replays in a few milliseconds: far fewer reports than log events.
        self.assertLess(len([l for l in lines if l["phase"] == "building"]), 4)

    def test_build_failure(self):
        self.log("fail.log")
        self.set("nix-exit", "1")
        p, lines = self.rebuild()
        self.assertEqual(p.returncode, 1)
        self.assertEqual(lines[-1]["phase"], "failed")
        self.assertEqual(lines[-1]["error"], "make: *** [Makefile:12: all] Error 2")
        self.assertEqual(self.calls(), [])  # nothing was activated
        self.assertIn("make: ***", slurp(lines[-1]["log"]))

    def test_wrong_password_fails_before_activating(self):
        self.log("ok.log")
        self.set("sudo-exit", "1")
        p, lines = self.rebuild()
        self.assertEqual(p.returncode, 1)
        self.assertNotIn("activating", [l["phase"] for l in lines])
        self.assertEqual(lines[-1]["error"], "sudo: authentication failed")

    def test_activation_failure(self):
        self.log("ok.log")
        open(os.path.join(self.stubs, "activate-fail"), "w").close()
        p, lines = self.rebuild()
        self.assertEqual(p.returncode, 4)
        self.assertEqual((lines[-1]["phase"], lines[-1]["error"]), ("failed", "Failed to restart sshd.service"))

    def test_build_mode_never_activates(self):
        self.log("ok.log")
        p, lines = self.rebuild("build")
        self.assertEqual(p.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertEqual((lines[-1]["phase"], lines[-1]["mode"]), ("done", "build"))

    def test_dry_mode_and_extra_args(self):
        self.log("ok.log")
        p, lines = self.rebuild("dry", "--show-trace")
        self.assertEqual(p.returncode, 0)
        args = slurp(os.path.join(self.stubs, "nix-args"))
        self.assertIn("--dry-run", args)
        self.assertIn("--show-trace", args)
        self.assertIn("/repo#nixosConfigurations.testhost.config.system.build.toplevel", args)
        self.assertEqual(self.calls(), [])

    def test_works_exactly_the_same_without_the_shell(self):
        self.log("ok.log")
        with_shell, _ = self.rebuild()
        self.assertEqual(with_shell.returncode, 0)
        self.set("calls", "")
        without, lines = self.rebuild(island=False)
        self.assertEqual(lines, [])
        self.assertEqual(without.returncode, 0)
        self.assertEqual(without.stdout, with_shell.stdout)
        self.log("fail.log")
        self.set("nix-exit", "1")
        self.assertEqual(self.rebuild(island=False)[0].returncode, 1)

    def test_nom_gets_the_whole_stream(self):
        self.log("ok.log")
        self.rebuild()
        with open(os.path.join(self.stubs, "nom-in")) as f:
            self.assertEqual(f.read(), slurp(os.path.join(FIX, "ok.log")))


if __name__ == "__main__":
    unittest.main()
