"""Tell the Quickshell island when an interactive Claude Code session needs the user.

  claude-island hook             a Claude Code hook: the event payload is on stdin
  claude-island focus SESSION    raise the terminal window that session runs in
  claude-island resolve SESSION  print the window address `focus` would raise

A hook must never get in Claude Code's way, so `hook` exits 0 whatever happens, does nothing
unless the shell is listening, and does nothing for any session that is not Claude Code run by
hand in a terminal (the SDK, `claude -p`, T3 Code and subagents all set other entrypoints).
See home/claude.nix for the events it is registered on.
"""

import json
import os
import re
import signal
import socket
import sys
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
SOCKET = os.environ.get("CLAUDE_ISLAND_SOCKET") or os.path.join(RUNTIME, "quickshell-island.sock")
STATE_DIR = os.environ.get("CLAUDE_ISLAND_STATE") or os.path.join(RUNTIME, "claude-island")
PROC = os.environ.get("CLAUDE_ISLAND_PROC") or "/proc"

# Windows a terminal can be in; `focus` never raises anything else.
TERMINALS = ("com.mitchellh.ghostty", "ghostty", "kitty", "foot", "Alacritty", "org.wezfurlong.wezterm")

CLAUDE_COMMS = ("claude", ".claude-wrapped", "claude-code")


# ---- gating ----------------------------------------------------------------------------


def wanted_env(env):
    """Whether this process was started by a Claude Code run by hand in a terminal.

    Interactive sessions have the entrypoint "cli"; `claude -p` is rewritten to "sdk-cli" and
    the SDK, the desktop app, IDEs and T3 Code have their own. Child sessions (a subagent
    process Claude started) and anything T3 Code launched are refused as well.
    """
    if env.get("CLAUDE_ISLAND") == "0":
        return False
    if env.get("CLAUDE_CODE_ENTRYPOINT") != "cli":
        return False
    if env.get("CLAUDE_CODE_CHILD_SESSION") or env.get("CLAUDE_CODE_SESSION_ATTENDED") == "0":
        return False
    return not any(key.startswith("T3CODE_") for key in env)


def read_proc(pid, name):
    try:
        with open(f"{PROC}/{pid}/{name}", "rb") as f:
            return f.read()
    except OSError:
        return b""


def parent_of(pid):
    stat = read_proc(pid, "stat").decode("utf-8", "replace")
    # "pid (comm) S ppid ...": comm may hold spaces and parentheses.
    tail = stat.rpartition(")")[2].split()
    try:
        return int(tail[1])
    except (IndexError, ValueError):
        return 0


def comm_of(pid):
    return read_proc(pid, "comm").decode("utf-8", "replace").strip()


def ancestors(pid, limit=24):
    out = []
    while pid > 1 and len(out) < limit:
        out.append(pid)
        pid = parent_of(pid)
    return out


def claude_process(chain):
    """The pid of Claude Code in a process's ancestry, else 0."""
    for pid in chain:
        if comm_of(pid) in CLAUDE_COMMS:
            return pid
        argv0 = read_proc(pid, "cmdline").split(b"\0", 1)[0]
        if os.path.basename(argv0) == b"claude":
            return pid
    return 0


def terminal_of(pid):
    """The tty a process reads from, "" when its stdin is not a terminal."""
    try:
        target = os.readlink(f"{PROC}/{pid}/fd/0")
    except OSError:
        return ""
    return target if target.startswith(("/dev/pts/", "/dev/tty")) else ""


# ---- the project -----------------------------------------------------------------------


def project_of(cwd):
    """The git root's name, else the working directory's."""
    here = cwd
    for _ in range(40):
        if os.path.exists(os.path.join(here, ".git")):
            return os.path.basename(here) or here
        parent = os.path.dirname(here)
        if parent == here:
            break
        here = parent
    return os.path.basename(cwd.rstrip("/")) or cwd


def tool_detail(name, tool_input):
    """`Bash(nix build .#x)` for the permission card's well."""
    if not isinstance(tool_input, dict):
        return name
    for key in ("command", "file_path", "path", "url", "pattern", "query", "description"):
        value = tool_input.get(key)
        if isinstance(value, str) and value.strip():
            return f"{name}({' '.join(value.split())[:160]})"
    return name


def digest(text, limit=240):
    """The first couple of lines of an assistant message, markdown noise removed."""
    lines = []
    for line in (text or "").splitlines():
        line = re.sub(r"^[#>*\-\s]+", "", line.strip())
        line = re.sub(r"[`*_]", "", line)
        if line:
            lines.append(line)
        if len(lines) == 2:
            break
    return " ".join(lines)[:limit]


# ---- Hyprland --------------------------------------------------------------------------


def hypr_socket():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        return ""
    return os.path.join(RUNTIME, "hypr", sig, ".socket.sock")


def hypr(command, timeout=1.0):
    """One request on Hyprland's command socket (what hyprctl sends), its reply or ""."""
    path = hypr_socket()
    if not path:
        return ""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect(path)
        s.sendall(command.encode())
        chunks = []
        while True:
            data = s.recv(65536)
            if not data:
                break
            chunks.append(data)
        return b"".join(chunks).decode("utf-8", "replace")
    except OSError:
        return ""
    finally:
        s.close()


def hypr_json(command):
    try:
        return json.loads(hypr("j/" + command))
    except ValueError:
        return None


def is_terminal(client):
    cls = client.get("class") or client.get("initialClass") or ""
    return cls.startswith(TERMINALS)


def active_terminal():
    """The address of the focused window when it is a terminal, else ""."""
    window = hypr_json("activewindow")
    if isinstance(window, dict) and window.get("address") and is_terminal(window):
        return window["address"]
    return ""


def resolve_window(state, clients):
    """Which window a session runs in: (address, how sure) or ("", "none").

    Ghostty hosts every window in one process, so the process tree alone only names the
    window when it is the only one; a terminal multiplexer (herdr) also detaches the session
    from the window's process tree. The window that had focus when the user last sent this
    session a prompt is the next best evidence, then a title that names the project.
    """
    terminals = [c for c in clients if c.get("mapped", True) and is_terminal(c)]
    if not terminals:
        return "", "none"
    chain = set(state.get("chain") or [])
    by_tree = [c for c in terminals if c.get("pid") in chain]
    if len(by_tree) == 1:
        return by_tree[0]["address"], "process"
    pool = by_tree or terminals
    recorded = state.get("window") or ""
    for c in pool:
        if c["address"] == recorded:
            return recorded, "focus"
    names = {n.lower() for n in (state.get("project"), os.path.basename(state.get("cwd") or "")) if n}
    titled = [c for c in pool if any(n in (c.get("title") or "").lower() for n in names)]
    if len(titled) == 1:
        return titled[0]["address"], "title"
    # No evidence: the terminal used most recently, which is a guess and is reported as one.
    pool = sorted(pool, key=lambda c: c.get("focusHistoryID", 1 << 30))
    return pool[0]["address"], "guess"


# ---- state and the shell ---------------------------------------------------------------


def state_path(session):
    return os.path.join(STATE_DIR, re.sub(r"[^A-Za-z0-9_.-]", "_", session) + ".json")


def load_state(session):
    try:
        with open(state_path(session)) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_state(session, state):
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    tmp = state_path(session) + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, state_path(session))


def mark_asking(session):
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    open(state_path(session) + ".asking", "w").close()


def send(message):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(0.25)
    try:
        s.connect(SOCKET)
        s.sendall((json.dumps(message, separators=(",", ":")) + "\n").encode())
    finally:
        s.close()


# ---- hook ------------------------------------------------------------------------------


def hook(raw, env):
    """Handle one event. `raw` is the payload as Claude Code sent it."""
    if not wanted_env(env) or not os.path.exists(SOCKET):
        return
    # Cheapest path: PostToolUse runs on every tool call and matters only after a permission
    # prompt, so it is answered from the session id alone.
    quick = re.search(rb'"session_id"\s*:\s*"([^"]+)"', raw[:4096])
    if quick and b'"PostToolUse"' in raw[:4096] and not os.path.exists(state_path(quick.group(1).decode()) + ".asking"):
        return
    try:
        event = json.loads(raw)
    except ValueError:
        return
    name = event.get("hook_event_name", "")
    session = event.get("session_id", "")
    if not session:
        return

    chain = ancestors(os.getppid())
    claude = claude_process(chain)
    if not claude or not terminal_of(claude):
        return

    cwd = event.get("cwd") or os.getcwd()
    # `pid` lets the shell notice a session that died without saying so; `window` is the terminal
    # window the user last prompted it from, which the shell compares with the focused one.
    base = {"src": "claude", "session": session, "project": project_of(cwd), "cwd": cwd, "pid": claude, "window": load_state(session).get("window", ""), "at": int(time.time() * 1000)}
    asking = state_path(session) + ".asking"

    if name in ("SessionStart", "UserPromptSubmit"):
        state = load_state(session)
        state.update(chain=chain, tty=terminal_of(claude), cwd=cwd, project=base["project"], pid=claude)
        window = active_terminal()
        if window:
            state["window"] = window
        save_state(session, state)
        if name == "UserPromptSubmit":
            send(dict(base, op="clear"))
    elif name == "SessionEnd":
        send(dict(base, op="clear", ended=True))
        for path in (state_path(session), asking):
            try:
                os.unlink(path)
            except OSError:
                pass
    elif name == "PermissionRequest":
        mark_asking(session)
        send(dict(base, op="state", state="permission", detail=tool_detail(event.get("tool_name", "a tool"), event.get("tool_input"))))
    elif name == "Notification":
        kind = event.get("notification_type", "")
        if kind == "permission_prompt":
            mark_asking(session)
            send(dict(base, op="state", state="permission", message=event.get("message", "")))
        elif kind == "elicitation_dialog":
            send(dict(base, op="state", state="question", message=event.get("message", "")))
    elif name == "PostToolUse":
        try:
            os.unlink(asking)
        except OSError:
            return
        send(dict(base, op="clear", why="answered"))
    elif name == "Stop":
        try:
            os.unlink(asking)
        except OSError:
            pass
        send(dict(base, op="state", state="finished", message=digest(event.get("last_assistant_message"))))


def run_hook():
    signal.signal(signal.SIGALRM, lambda *_: os._exit(0))
    signal.alarm(2)
    try:
        if wanted_env(os.environ) and os.path.exists(SOCKET):
            hook(sys.stdin.buffer.read(1 << 20), os.environ)
    except BaseException:  # noqa: BLE001 - a hook may never fail Claude Code
        pass
    os._exit(0)


# ---- focus -----------------------------------------------------------------------------


def focus(session, clients=None):
    """Raise the session's terminal. Returns (address, how) and prints nothing."""
    state = load_state(session)
    if not state:
        return "", "unknown session"
    if clients is None:
        clients = hypr_json("clients") or []
    address, how = resolve_window(state, clients)
    if address:
        hypr(f'dispatch hl.dsp.focus({{ window = "address:{address}" }})')
    return address, how


def main(argv):
    if len(argv) >= 2 and argv[1] == "hook":
        run_hook()
    if len(argv) >= 3 and argv[1] in ("focus", "resolve"):
        clients = None
        if "--clients" in argv:
            with open(argv[argv.index("--clients") + 1]) as f:
                clients = json.load(f)
        if argv[1] == "resolve":
            address, how = resolve_window(load_state(argv[2]), clients if clients is not None else hypr_json("clients") or [])
        else:
            address, how = focus(argv[2], clients)
        print(f"{address} {how}")
        return 0 if address else 1
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
