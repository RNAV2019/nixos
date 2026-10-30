"""Build and switch this NixOS system, and tell the Quickshell island how it is going.

  rebuild [MODE] [NIX ARGS...]

MODE is switch (the default), boot, test, build (build and diff only) or dry (what would be
built). The build is `nix build` of the host's toplevel with its internal-json log, which this
program reads for the island and passes on to nix-output-monitor for the terminal; the diff
against the running system is shown and saved; then the result is activated with
`nixos-rebuild --store-path ... --elevate sudo`, so sudo asks for its password exactly where it
would have. Without the island running it behaves as `sudo nixos-rebuild switch --flake` did.

The island hears about it on its socket, one JSON line per change, rate limited:
  phase: evaluating | building | activating | done | failed | cancelled

Environment: REBUILD_FLAKE (default: this repo), REBUILD_HOST (default: the hostname),
REBUILD_INSTALLABLE (replaces flake#host...toplevel, for tests), REBUILD_PLAIN=1 (no nom),
REBUILD_CURRENT (the running system to diff against, /run/current-system).
"""

import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time

REPO = "@repoDir@"
# nom and dix, from the store, are looked for after the PATH; nix, nixos-rebuild and sudo are the system's.
TOOLS = "@path@"
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
SOCKET = os.environ.get("REBUILD_SOCKET") or os.path.join(RUNTIME, "quickshell-island.sock")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "rebuild")
MODES = ("switch", "boot", "test", "build", "dry")
ACTIVATING = ("switch", "boot", "test")
# Progress is sent at most this often; a phase change always goes at once.
RATE = 0.25
KEEP = 12

PLAN = re.compile(r"^(?:these (\d+) derivations|this derivation) will be built")
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")

# Activity types in nix's internal-json log (libutil/logging.hh).
BUILD, BUILDS, COPY_PATHS, SUBSTITUTE = 105, 104, 103, 108
RES_LOG_LINE, RES_PROGRESS = 101, 105


def strip(text):
    return ANSI.sub("", text)


def drv_name(path):
    """`firefox-141.0` from /nix/store/<hash>-firefox-141.0.drv."""
    name = os.path.basename(path)
    name = re.sub(r"^[a-z0-9]{32}-", "", name)
    return name[:-4] if name.endswith(".drv") else name


# ---- the log ---------------------------------------------------------------------------


class Progress:
    """What the internal-json log says so far: phase, n/m, the current derivation, the error."""

    def __init__(self):
        self.phase = "evaluating"
        self.done = 0
        self.total = 0
        self.kind = "builds"
        self.current = ""
        self.running = {}
        self.error = ""
        self.last_line = ""
        self.builds_id = None
        self.copy_id = None
        self.announced = False
        self.text = []
        self.sink = None

    def say(self, text):
        """A line of the readable log, also written to the saved file as it comes."""
        self.text.append(text)
        if self.sink is not None:
            try:
                self.sink.write(text + "\n")
                self.sink.flush()
            except OSError:
                self.sink = None

    def feed(self, line):
        """One line of nix's stderr. Returns True when something the island shows changed."""
        if not line.startswith("@nix "):
            text = strip(line).rstrip()
            if text:
                self.say(text)
            return False
        try:
            event = json.loads(line[5:])
        except ValueError:
            return False
        action = event.get("action")
        if action == "start":
            return self.start(event)
        if action == "stop":
            if self.running.pop(event.get("id"), None) is not None:
                self.done += 1
                return True
            return False
        if action == "result":
            return self.result(event)
        if action == "msg":
            return self.msg(event)
        return False

    def start(self, event):
        kind = event.get("type")
        fields = event.get("fields") or []
        if kind == BUILDS:
            self.builds_id = event["id"]
        elif kind == COPY_PATHS:
            self.copy_id = event["id"]
        elif kind == BUILD and fields:
            self.running[event["id"]] = drv_name(fields[0])
            self.current = drv_name(fields[0])
            self.phase = "building"
            return True
        elif kind == SUBSTITUTE and fields:
            self.current = drv_name(fields[0])
            self.phase = "building"
            return True
        return False

    def result(self, event):
        kind = event.get("type")
        fields = event.get("fields") or []
        if kind == RES_LOG_LINE and fields and isinstance(fields[0], str):
            line = strip(fields[0]).strip()
            owner = self.running.get(event.get("id"), "")
            self.say(f"{owner}> {line}" if owner else line)
            if line:
                self.last_line = line
            return False
        if kind == RES_PROGRESS and len(fields) >= 2:
            # nix's own tally counts a goal too many, so it only stands in when the plan was not announced.
            if event.get("id") == self.builds_id and fields[1] > 0 and not self.announced:
                self.done, self.total, self.kind = fields[0], fields[1], "derivations"
                return True
            if event.get("id") == self.copy_id and fields[1] > 0 and self.total == 0:
                self.done, self.total, self.kind = fields[0], fields[1], "paths"
                return True
        return False

    def msg(self, event):
        text = strip(event.get("msg", ""))
        level = event.get("level", 3)
        if level <= 3 and not text.startswith("linking "):
            self.say(text)
        if level == 0 and text.startswith("error:"):
            self.error = self.reason(text)
        plan = PLAN.search(text)
        if plan:
            self.announced = True
            self.total = int(plan.group(1) or 1)
            self.kind = "derivations"
            self.phase = "building"
            return True
        return False

    def reason(self, text):
        """The most useful single line of a nix error: a builder's last words, else its headline."""
        logged = [l.strip()[1:].strip() for l in text.splitlines() if l.strip().startswith(">")]
        if logged and logged[-1]:
            return logged[-1]
        head = text.splitlines()[0][len("error:") :].strip() if text.splitlines() else ""
        return head or text.strip()

    def failure(self):
        return self.error or self.last_line or "the build failed"

    def snapshot(self):
        return {"done": self.done, "total": self.total, "unit": self.kind, "current": self.current}


# ---- the island ------------------------------------------------------------------------


class Island:
    """Rate-limited reports to the shell's socket; silent when nobody listens.

    A change of phase goes at once. Progress within a phase goes at most every RATE seconds,
    and the latest one is held and sent when that has passed, so a long silent build still
    shows where it got to.
    """

    def __init__(self, base):
        self.base = base
        self.last = 0.0
        self.sent = None
        self.pending = None
        self.timer = None
        self.lock = threading.Lock()

    def report(self, phase, force=True, **fields):
        body = dict(self.base, phase=phase, **fields)
        with self.lock:
            if self.timer:
                self.timer.cancel()
                self.timer = None
            if self.pending is not None and (force or self.pending["phase"] != phase):
                self.transmit(self.pending)
                self.pending = None
            elapsed = time.monotonic() - self.last
            quiet = self.sent is not None and self.sent["phase"] == phase
            if force or not quiet or elapsed >= RATE:
                self.pending = None
                self.transmit(body)
                return
            self.pending = body
            self.timer = threading.Timer(RATE - elapsed, self.flush)
            self.timer.daemon = True
            self.timer.start()

    def flush(self):
        with self.lock:
            body, self.pending, self.timer = self.pending, None, None
            if body is not None:
                self.transmit(body)

    def transmit(self, body):
        if body == self.sent:
            return
        self.last = time.monotonic()
        self.sent = body
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.2)
            try:
                s.connect(SOCKET)
                s.sendall((json.dumps(body, separators=(",", ":")) + "\n").encode())
            finally:
                s.close()
        except OSError:
            pass


# ---- the diff --------------------------------------------------------------------------

ENTRY = re.compile(r"^\[([A-Z.*]+)\]\s+(\S+)\s+(.*)$")
SIZE_TAIL = re.compile(r",?\s*[+-]?[\d.]+ [KMGT]?i?B$")


def short_version(rest):
    """`158.0 → 158.0.1` out of dix's `158.0-doc, 158.0 -> 158.0.1-doc, 158.0.1, +1 MiB`."""
    if " -> " not in rest:
        return ""
    old, new = rest.split(" -> ", 1)
    new = SIZE_TAIL.sub("", new)

    def main(side):
        items = [i.strip() for i in side.split(",") if i.strip() and i.strip() != "<unchanged>"]
        items = [re.sub(r" ×\d+$", "", i) for i in items]
        return min(items, key=len) if items else ""

    a, b = main(old), main(new)
    return f"{a} → {b}" if a and b else ""


def summarise_diff(text):
    """(count of packages that changed, a short list: `firefox 158.0 → 158.0.1, helix, +9 more`)."""
    names = []
    for line in text.splitlines():
        m = ENTRY.match(line)
        if not m or m.group(1)[0] not in "UDAR":
            continue
        names.append((m.group(1)[0], m.group(2), short_version(m.group(3))))
    # Updates first, then the rest; the version is shown for the first two only.
    names.sort(key=lambda n: "UDAR".index(n[0]))
    shown = [f"{n} {v}".strip() if i < 2 else n for i, (_, n, v) in enumerate(names[:4])]
    more = len(names) - len(shown)
    if more > 0:
        shown.append(f"+{more} more")
    return len(names), ", ".join(shown)


# ---- the run ---------------------------------------------------------------------------


def installable(host):
    custom = os.environ.get("REBUILD_INSTALLABLE")
    if custom:
        return custom
    flake = os.environ.get("REBUILD_FLAKE") or REPO
    return f"{flake}#nixosConfigurations.{host}.config.system.build.toplevel"


def prune(prefix):
    try:
        files = sorted(f for f in os.listdir(STATE) if f.startswith(prefix))
    except OSError:
        return
    for old in files[:-KEEP]:
        try:
            os.unlink(os.path.join(STATE, old))
        except OSError:
            pass


def pump(proc, progress, island, sink):
    """Read nix's stderr: parse it for the island, pass every line on to `sink` (nom), or print
    what a person would read of it when there is no nom."""
    for raw in iter(proc.stderr.readline, b""):
        line = raw.decode("utf-8", "replace")
        seen = len(progress.text)
        changed = progress.feed(line)
        if sink is not None:
            try:
                sink.write(raw)
                sink.flush()
            except (BrokenPipeError, ValueError):
                sink = None
        else:
            for text in progress.text[seen:]:
                sys.stderr.write(text + "\n")
        if changed:
            island.report(progress.phase, force=False, **progress.snapshot())


def build(target, extra, progress, island, dry):
    """Run nix build; returns (exit code, out path)."""
    cmd = ["nix", "build", target, "--no-link", "--log-format", "internal-json", "-v"]
    cmd += ["--dry-run"] if dry else ["--print-out-paths"]
    cmd += extra
    nom = None
    if shutil.which("nom") and os.environ.get("REBUILD_PLAIN") != "1":
        nom = subprocess.Popen(["nom", "--json"], stdin=subprocess.PIPE)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out = []
    reader = threading.Thread(target=lambda: out.append(proc.stdout.read().decode()))
    reader.start()
    try:
        pump(proc, progress, island, nom.stdin if nom else None)
        code = proc.wait()
    except KeyboardInterrupt:
        proc.send_signal(signal.SIGINT)
        proc.wait()
        raise
    finally:
        reader.join()
        if nom:
            try:
                nom.stdin.close()
            except OSError:
                pass
            nom.wait()
    paths = [l for l in "".join(out).split() if l.startswith("/nix/store/")]
    return code, paths[-1] if paths else ""


def diff_against_running(new):
    """Show and return dix's comparison of /run/current-system with `new`."""
    running = os.environ.get("REBUILD_CURRENT") or "/run/current-system"
    if not shutil.which("dix") or not os.path.exists(running):
        return ""
    tty = sys.stdout.isatty()
    shown = subprocess.run(["dix", "--color", "always" if tty else "never", running, new], capture_output=True, text=True)
    sys.stdout.write(shown.stdout)
    sys.stdout.flush()
    return shown.stdout


def activate(mode, out, island, base_fields, progress):
    """Hand the built system to nixos-rebuild, which runs the privileged half through sudo."""
    # Ask for the password here, before the island says "Activating": the wait is the user's.
    if shutil.which("sudo") and subprocess.run(["sudo", "-v"]).returncode != 0:
        return 1, "sudo: authentication failed"
    island.report("activating", **base_fields)
    cmd = ["nixos-rebuild", mode, "--store-path", out, "--elevate", "sudo", "--no-reexec"]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    last = ""
    for raw in iter(proc.stdout.readline, b""):
        sys.stdout.buffer.write(raw)
        sys.stdout.flush()
        text = strip(raw.decode("utf-8", "replace")).strip()
        if text:
            last = text
            progress.say(text)
            island.report("activating", force=False, detail=text[:200], **base_fields)
    return proc.wait(), last


def generation():
    try:
        m = re.match(r"system-(\d+)-link", os.readlink("/nix/var/nix/profiles/system"))
        return int(m.group(1)) if m else 0
    except OSError:
        return 0


def main(argv):
    if TOOLS and not TOOLS.startswith("@"):
        os.environ["PATH"] = os.environ.get("PATH", "") + ":" + TOOLS
    args = argv[1:]
    if args and args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    mode = "switch"
    if args and args[0] in MODES:
        mode, args = args[0], args[1:]
    host = os.environ.get("REBUILD_HOST") or socket.gethostname()
    started = int(time.time() * 1000)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    os.makedirs(STATE, exist_ok=True)
    log_path = os.path.join(STATE, f"rebuild-{stamp}.log")
    diff_path = os.path.join(STATE, f"rebuild-{stamp}.diff")
    base = {"src": "rebuild", "id": f"{os.getpid()}-{started}", "mode": mode, "host": host, "started": started}
    island = Island(base)
    progress = Progress()
    fields = {"log": log_path}

    # Written as it goes, so Show log has something to open while the build runs.
    progress.sink = open(log_path, "w")

    def finish(code, error="", **more):
        progress.sink.close()
        prune("rebuild-")
        island.report("failed" if code else "done", error=error, ended=int(time.time() * 1000), **fields, **more)
        return code

    island.report("evaluating", **fields)
    try:
        code, out = build(installable(host), args, progress, island, mode == "dry")
        if code != 0:
            return finish(code, progress.failure())
        if mode == "dry":
            return finish(0, summary="Nothing was built")
        text = diff_against_running(out)
        count, names = summarise_diff(strip(text))
        if text:
            with open(diff_path, "w") as f:
                f.write(text)
            fields["diff"] = diff_path
        if mode in ACTIVATING:
            code, last = activate(mode, out, island, fields, progress)
            if code != 0:
                return finish(code, last or "activation failed")
        return finish(0, changed=count, summary=names, generation=generation() if mode in ("switch", "boot") else 0)
    except KeyboardInterrupt:
        island.report("cancelled", **fields)
        return 130


if __name__ == "__main__":
    sys.exit(main(sys.argv))
