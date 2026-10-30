"""What the Quickshell island needs from udisks2 for USB drives.

  island-usb watch           print the removable filesystems as one JSON line, now and whenever
                             they change (or their free space does, every 30 s)
  island-usb snapshot        the same, once
  island-usb mount DEVICE    mount it (udisks asks polkit, which the shell's agent answers)
  island-usb eject DEVICE    unmount everything on the drive DEVICE is part of, then power it off

`mount` and `eject` print one JSON line: {"ok": true, ...} or {"ok": false, "error": ..., "message": ...}.
The error is "busy" when something still uses the drive (with the names of those programs in
"blockers"), "denied" when polkit refused, else "failed".
"""

import json
import os
import re
import select
import subprocess
import sys
import time

# gdbus, busctl and udisksctl: the store's, looked for after the PATH.
TOOLS = "@path@"
UDISKS = "org.freedesktop.UDisks2"
ROOT = "/org/freedesktop/UDisks2"
REFRESH = 30.0
DEBOUNCE = 0.25


def text(value):
    """A NUL-terminated byte string as udisks sends it."""
    return bytes(value).split(b"\0", 1)[0].decode("utf-8", "replace") if value else ""


def prop(interface, name, default=None):
    entry = (interface or {}).get(name)
    return entry["data"] if entry else default


def parse(managed, statvfs=os.statvfs):
    """The removable filesystems in `GetManagedObjects` output (busctl --json=short)."""
    objects = managed["data"][0]

    def iface(path, name):
        return objects.get(path, {}).get(f"{UDISKS}.{name}")

    # The whole disk of each drive: its block device that is not a partition.
    disks = {}
    for path in sorted(objects):
        block = iface(path, "Block")
        if block is not None and iface(path, "Partition") is None:
            disks.setdefault(prop(block, "Drive", "/"), text(prop(block, "Device")))

    out = []
    for path in objects:
        block = iface(path, "Block")
        fs = iface(path, "Filesystem")
        if block is None or fs is None:
            continue
        if prop(block, "IdUsage") != "filesystem" or prop(block, "HintIgnore", False):
            continue
        # A cleartext device of an unlocked container belongs to the drive of its backing device.
        drive_path = prop(block, "Drive", "/")
        backing = prop(block, "CryptoBackingDevice", "/")
        if drive_path == "/" and backing != "/":
            drive_path = prop(iface(backing, "Block"), "Drive", "/")
        drive = iface(drive_path, "Drive")
        if drive is None:
            continue
        if not (prop(drive, "Removable", False) or prop(drive, "ConnectionBus", "") == "usb"):
            continue
        mounts = [text(m) for m in prop(fs, "MountPoints", [])]
        entry = {
            "id": path.rsplit("/", 1)[-1],
            "device": text(prop(block, "Device")),
            "label": prop(block, "IdLabel", "") or "",
            "fs": prop(block, "IdType", "") or "",
            "size": prop(block, "Size", 0),
            "readOnly": prop(block, "ReadOnly", False),
            "mounts": mounts,
            "drive": drive_path.rsplit("/", 1)[-1],
            "disk": disks.get(drive_path, ""),
            "driveName": " ".join(p for p in (prop(drive, "Vendor", "").strip(), prop(drive, "Model", "").strip()) if p),
            "canPowerOff": prop(drive, "CanPowerOff", False),
        }
        if mounts:
            try:
                st = statvfs(mounts[0])
                entry["total"] = st.f_blocks * st.f_frsize
                entry["free"] = st.f_bavail * st.f_frsize
                entry["used"] = entry["total"] - st.f_bfree * st.f_frsize
            except OSError:
                pass
        out.append(entry)
    out.sort(key=lambda e: e["device"])
    return out


def managed_objects():
    p = subprocess.run(["busctl", "--system", "--json=short", "call", UDISKS, ROOT, "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"], capture_output=True, text=True, timeout=10)
    if p.returncode != 0:
        raise OSError(p.stderr.strip() or "busctl failed")
    return json.loads(p.stdout)


def snapshot():
    return {"drives": parse(managed_objects())}


def stable(snap):
    """The snapshot without the numbers that move on their own."""
    return json.dumps([{k: v for k, v in d.items() if k not in ("used", "free", "total")} for d in snap["drives"]], sort_keys=True)


def emit(snap):
    sys.stdout.write(json.dumps(snap, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def watch():
    last = None
    sent = 0.0
    while True:
        monitor = None
        try:
            monitor = subprocess.Popen(["gdbus", "monitor", "--system", "--dest", UDISKS], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            pass
        due = 0.0
        while True:
            now = time.monotonic()
            if now >= due or now - sent >= REFRESH:
                try:
                    snap = snapshot()
                except (OSError, ValueError, subprocess.TimeoutExpired):
                    snap = None
                if snap is not None:
                    if last is None or stable(snap) != stable(last) or now - sent >= REFRESH:
                        emit(snap)
                        sent = now
                    last = snap
                due = float("inf")
            wait = 3.0 if monitor is None else max(0.0, min(due - time.monotonic(), REFRESH))
            if monitor is None:
                time.sleep(wait)
                due = 0.0
                continue
            ready, _, _ = select.select([monitor.stdout], [], [], min(wait, REFRESH))
            if ready:
                if not monitor.stdout.readline():
                    break
                if due == float("inf"):
                    due = time.monotonic() + DEBOUNCE
            elif due == float("inf"):
                due = 0.0
        # udisks went away or gdbus died: start over shortly.
        monitor.kill()
        time.sleep(2)


def blockers(mountpoint):
    """Names of this user's programs that hold files or a working directory under `mountpoint`."""
    names = set()
    root = mountpoint.rstrip("/") + "/"
    for pid in filter(str.isdigit, os.listdir("/proc")):
        base = f"/proc/{pid}"
        try:
            targets = [os.readlink(f"{base}/cwd")] + [os.readlink(f"{base}/fd/{fd}") for fd in os.listdir(f"{base}/fd")]
            if any(t == mountpoint or t.startswith(root) for t in targets):
                with open(f"{base}/comm") as f:
                    names.add(f.read().strip())
        except OSError:
            continue
    return sorted(names)


def classify(stderr):
    low = stderr.lower()
    if "busy" in low:
        return "busy"
    if "not authorized" in low or "authentication" in low or "dismissed" in low:
        return "denied"
    return "failed"


def clean(stderr):
    """The last useful sentence of udisksctl's complaint: `Error unmounting /dev/sdb1: GDBus.Error:...: msg`."""
    line = stderr.strip().splitlines()[-1] if stderr.strip() else "udisksctl failed"
    return re.sub(r"^Error [^:]*: (GDBus\.Error:[\w.]+: )?", "", line).strip()


def udisksctl(*args):
    return subprocess.run(["udisksctl", *args], capture_output=True, text=True, timeout=120)


def result(**fields):
    sys.stdout.write(json.dumps(fields) + "\n")
    return 0 if fields.get("ok") else 1


def mount(device):
    p = udisksctl("mount", "-b", device)
    if p.returncode != 0:
        return result(ok=False, error=classify(p.stderr), message=clean(p.stderr))
    m = re.search(r" at (.+?)\.?$", p.stdout.strip())
    return result(ok=True, mountpoint=m.group(1) if m else "")


def eject(device):
    drives = parse(managed_objects())
    mine = next((d for d in drives if d["device"] == device or d["id"] == device), None)
    if mine is None:
        return result(ok=False, error="gone", message="The drive is already gone")
    siblings = [d for d in drives if d["drive"] == mine["drive"]]
    for fs in siblings:
        for point in fs["mounts"]:
            p = udisksctl("unmount", "-b", fs["device"])
            if p.returncode != 0:
                error = classify(p.stderr)
                return result(ok=False, error=error, message=clean(p.stderr), blockers=blockers(point) if error == "busy" else [])
    if mine["canPowerOff"]:
        p = udisksctl("power-off", "-b", mine["disk"] or mine["device"])
        if p.returncode != 0:
            return result(ok=False, error=classify(p.stderr), message=clean(p.stderr), unmounted=True)
    return result(ok=True, name=mine["label"] or mine["driveName"] or mine["device"])


def main(argv):
    if TOOLS and not TOOLS.startswith("@"):
        os.environ["PATH"] = os.environ.get("PATH", "") + ":" + TOOLS
    try:
        if len(argv) >= 2 and argv[1] == "watch":
            watch()
        if len(argv) >= 2 and argv[1] == "snapshot":
            emit(snapshot())
            return 0
        if len(argv) >= 3 and argv[1] == "mount":
            return mount(argv[2])
        if len(argv) >= 3 and argv[1] == "eject":
            return eject(argv[2])
    except KeyboardInterrupt:
        return 130
    except (OSError, ValueError, subprocess.TimeoutExpired) as e:
        if argv[1:2] in (["mount"], ["eject"]):
            return result(ok=False, error="failed", message=str(e))
        print(f"island-usb: {e}", file=sys.stderr)
        return 1
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
