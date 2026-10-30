"""Tests for island-usb: udisks parsing against the laptop's own object tree plus a made-up stick,
and mount / eject against stub tools."""

import importlib.machinery
import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import types
import unittest

BIN = os.environ["ISLAND_USB_BIN"]
FIX = os.environ["FIXTURES"]
NS = "org.freedesktop.UDisks2."


def load():
    loader = importlib.machinery.SourceFileLoader("island_usb", BIN)
    spec = importlib.util.spec_from_loader("island_usb", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def b(text):
    return {"type": "ay", "data": list(text.encode()) + [0]}


def v(kind, data):
    return {"type": kind, "data": data}


def laptop():
    with open(os.path.join(FIX, "laptop.json")) as f:
        return json.load(f)


def with_stick(managed, label="BACKUP", fs="exfat", mounts=("/run/media/ryan/BACKUP",), removable=True, bus="usb", ignore=False, usage="filesystem"):
    """The laptop's objects plus a stick: disk sdb, partition sdb1 carrying `fs`."""
    drive = "/org/freedesktop/UDisks2/drives/SanDisk_Ultra_123"
    objects = managed["data"][0]
    objects[drive] = {NS + "Drive": {"Removable": v("b", removable), "ConnectionBus": v("s", bus), "Vendor": v("s", "SanDisk"), "Model": v("s", "Ultra"), "CanPowerOff": v("b", True)}}
    objects["/org/freedesktop/UDisks2/block_devices/sdb"] = {NS + "Block": {"Device": b("/dev/sdb"), "Drive": v("o", drive), "IdUsage": v("s", ""), "Size": v("t", 64000000000)}, NS + "PartitionTable": {}}
    objects["/org/freedesktop/UDisks2/block_devices/sdb1"] = {
        NS + "Block": {"Device": b("/dev/sdb1"), "Drive": v("o", drive), "IdUsage": v("s", usage), "IdType": v("s", fs), "IdLabel": v("s", label), "Size": v("t", 63900000000), "HintIgnore": v("b", ignore), "ReadOnly": v("b", False)},
        NS + "Partition": {},
        NS + "Filesystem": {"MountPoints": v("aay", [list(m.encode()) + [0] for m in mounts])},
    }
    return managed


class Parse(unittest.TestCase):
    def setUp(self):
        self.mod = load()
        self.fake = lambda path: types.SimpleNamespace(f_blocks=1000, f_frsize=1000, f_bavail=300, f_bfree=300)

    def test_the_laptop_has_no_removable_filesystems(self):
        self.assertEqual(self.mod.parse(laptop()), [])

    def test_a_mounted_stick(self):
        [d] = self.mod.parse(with_stick(laptop()), statvfs=self.fake)
        self.assertEqual((d["device"], d["label"], d["fs"], d["size"]), ("/dev/sdb1", "BACKUP", "exfat", 63900000000))
        self.assertEqual((d["mounts"], d["drive"], d["disk"], d["driveName"]), (["/run/media/ryan/BACKUP"], "SanDisk_Ultra_123", "/dev/sdb", "SanDisk Ultra"))
        self.assertEqual((d["total"], d["free"], d["used"]), (1000000, 300000, 700000))

    def test_an_unmounted_stick_has_no_usage(self):
        [d] = self.mod.parse(with_stick(laptop(), mounts=()), statvfs=self.fake)
        self.assertEqual(d["mounts"], [])
        self.assertNotIn("used", d)

    def test_only_removable_filesystems_count(self):
        self.assertEqual(self.mod.parse(with_stick(laptop(), removable=False, bus="sata")), [])
        self.assertEqual(self.mod.parse(with_stick(laptop(), usage="crypto")), [])
        self.assertEqual(self.mod.parse(with_stick(laptop(), ignore=True)), [])
        # A USB disk that does not call itself removable still counts.
        self.assertEqual(len(self.mod.parse(with_stick(laptop(), removable=False, bus="usb"), statvfs=self.fake)), 1)

    def test_stable_ignores_usage(self):
        a = {"drives": [{"device": "/dev/sdb1", "free": 1}]}
        c = {"drives": [{"device": "/dev/sdb1", "free": 2}]}
        self.assertEqual(self.mod.stable(a), self.mod.stable(c))

    def test_error_words(self):
        self.assertEqual(self.mod.classify("Error unmounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.DeviceBusy: target is busy"), "busy")
        self.assertEqual(self.mod.classify("Error mounting: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorizedDismissed: Not authorized"), "denied")
        self.assertEqual(self.mod.clean("Error unmounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.DeviceBusy: target is busy"), "target is busy")


class Cli(unittest.TestCase):
    """mount / eject against stubs: busctl serves the object tree, udisksctl obeys a script."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stubs = os.path.join(self.tmp.name, "stubs")
        os.makedirs(self.stubs)
        self.tree = os.path.join(self.tmp.name, "tree.json")
        self.write("busctl", '#!/bin/sh\ncat "$STUB_TREE"\n')
        self.write("udisksctl", '#!/bin/sh\necho "udisksctl $*" >> "$STUB_DIR/calls"\n. "$STUB_DIR/udisksctl.sh"\n')
        self.script("exit 0")
        self.tree_json(with_stick(laptop()))

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, body):
        path = os.path.join(self.stubs, name)
        with open(path, "w") as f:
            f.write(body)
        os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)

    def script(self, body):
        with open(os.path.join(self.stubs, "udisksctl.sh"), "w") as f:
            f.write(body + "\n")

    def tree_json(self, managed):
        with open(self.tree, "w") as f:
            json.dump(managed, f)

    def run_cli(self, *args):
        env = {"PATH": self.stubs + ":" + os.environ["PATH"], "STUB_DIR": self.stubs, "STUB_TREE": self.tree}
        p = subprocess.run([BIN, *args], capture_output=True, text=True, env=env, timeout=30)
        calls = []
        if os.path.exists(os.path.join(self.stubs, "calls")):
            with open(os.path.join(self.stubs, "calls")) as f:
                calls = f.read().splitlines()
        return p, (json.loads(p.stdout.splitlines()[-1]) if p.stdout.strip() else None), calls

    def test_snapshot(self):
        p, out, _ = self.run_cli("snapshot")
        self.assertEqual(p.returncode, 0)
        self.assertEqual(out["drives"][0]["label"], "BACKUP")

    def test_mount(self):
        self.script('echo "Mounted /dev/sdb1 at /run/media/ryan/BACKUP."')
        p, out, calls = self.run_cli("mount", "/dev/sdb1")
        self.assertEqual((p.returncode, out), (0, {"ok": True, "mountpoint": "/run/media/ryan/BACKUP"}))
        self.assertEqual(calls, ["udisksctl mount -b /dev/sdb1"])

    def test_mount_denied(self):
        self.script('echo "Error mounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorizedDismissed: Not authorized to perform operation" >&2; exit 1')
        p, out, _ = self.run_cli("mount", "/dev/sdb1")
        self.assertEqual((p.returncode, out["error"], out["message"]), (1, "denied", "Not authorized to perform operation"))

    def test_eject_unmounts_then_powers_off_the_disk(self):
        p, out, calls = self.run_cli("eject", "/dev/sdb1")
        self.assertEqual((p.returncode, out), (0, {"ok": True, "name": "BACKUP"}))
        self.assertEqual(calls, ["udisksctl unmount -b /dev/sdb1", "udisksctl power-off -b /dev/sdb"])

    def test_eject_busy(self):
        self.script('case "$1" in unmount) echo "Error unmounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.DeviceBusy: target is busy" >&2; exit 1;; esac')
        p, out, calls = self.run_cli("eject", "/dev/sdb1")
        self.assertEqual((p.returncode, out["error"], out["message"]), (1, "busy", "target is busy"))
        self.assertEqual(out["blockers"], [])
        self.assertEqual(calls, ["udisksctl unmount -b /dev/sdb1"])  # never powered off

    def test_eject_unmounted_stick_only_powers_off(self):
        self.tree_json(with_stick(laptop(), mounts=()))
        p, out, calls = self.run_cli("eject", "/dev/sdb1")
        self.assertEqual(out["ok"], True)
        self.assertEqual(calls, ["udisksctl power-off -b /dev/sdb"])

    def test_eject_a_drive_that_is_gone(self):
        self.tree_json(laptop())
        p, out, _ = self.run_cli("eject", "/dev/sdb1")
        self.assertEqual((p.returncode, out["error"]), (1, "gone"))


if __name__ == "__main__":
    unittest.main()
