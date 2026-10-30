pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Removable drives, from `island-usb watch` (pkgs/island-usb), which reads udisks2 on the
// system bus and prints the USB filesystems as one JSON line whenever they change.
//
// A drive is mounted when the user asks (Open, on its moment or its card), not when it is
// plugged in: mounting makes the kernel parse whatever filesystem image is on the stick, and an
// unknown stick should not get that without being asked. Mounting goes through udisks and
// polkit, whose password prompt is the shell's own agent (Services/Polkit.qml). A drive that
// something else mounted (a file manager, gvfs) is shown like any other.
Singleton {
  id: root

  // The program; QUICKSHELL_ISLAND_USB stands in for it in tests.
  readonly property string program: Quickshell.env("QUICKSHELL_ISLAND_USB") || "island-usb"

  // Every removable filesystem now, as the program reports it, and the mounted ones.
  property var drives: []
  readonly property var mounted: drives.filter(d => d.mounts.length > 0)

  // Device -> true while it is being ejected (unmounted and powered off), or mounted for Open.
  property var ejecting: ({})
  property var mounting: ({})

  // Seen once the first snapshot is in: what was plugged in before is not news.
  property bool primed: false
  property var known: ({})

  signal inserted(var drive)
  signal ejected(string name)
  signal problem(string title, string message)

  function find(device) {
    return drives.find(d => d.device === device) || null;
  }

  function name(d) {
    return d.label || d.driveName || "USB drive";
  }

  function fsName(fs) {
    return ({
        exfat: "exFAT",
        vfat: "FAT32",
        ntfs: "NTFS",
        ntfs3: "NTFS",
        iso9660: "ISO 9660",
        udf: "UDF"
      })[fs] || fs;
  }

  // Decimal units, as drives are sold and as the design shows them ("59.5 GB").
  function bytes(n) {
    if (n >= 1e12)
      return (n / 1e12).toFixed(1) + " TB";
    if (n >= 1e9)
      return (n / 1e9).toFixed(1) + " GB";
    if (n >= 1e6)
      return Math.round(n / 1e6) + " MB";
    return Math.round(n / 1e3) + " kB";
  }

  function describe(d) {
    return fsName(d.fs) + " · " + bytes(d.size);
  }

  function mark(map, key, on) {
    var next = Object.assign({}, map);
    if (on)
      next[key] = true;
    else
      delete next[key];
    return next;
  }

  function apply(snapshot) {
    var next = {};
    snapshot.drives.forEach(d => next[d.id] = true);
    if (primed)
      snapshot.drives.filter(d => !known[d.id]).forEach(d => inserted(d));
    known = next;
    drives = snapshot.drives;
    primed = true;
  }

  // Mount if need be, then show its files.
  function open(device) {
    var d = find(device);
    if (!d)
      return;
    if (d.mounts.length > 0) {
      launcher.exec(["xdg-open", d.mounts[0]]);
      return;
    }
    if (mounting[device])
      return;
    mounting = mark(mounting, device, true);
    var run = mountComponent.createObject(root, {
      device: device
    });
    run.start();
  }

  function eject(device) {
    var d = find(device);
    if (!d || ejecting[device])
      return;
    ejecting = mark(ejecting, device, true);
    var run = ejectComponent.createObject(root, {
      device: device,
      label: name(d)
    });
    run.start();
  }

  // The program's last JSON line: {"ok": ...}.
  function verdict(text) {
    var lines = text.trim().split("\n");
    try {
      return JSON.parse(lines[lines.length - 1]);
    } catch (err) {
      return {
        ok: false,
        error: "failed",
        message: "The drive did not answer"
      };
    }
  }

  Component {
    id: mountComponent

    Process {
      id: run

      required property string device

      function start() {
        command = [root.program, "mount", device];
        running = true;
      }

      stdout: StdioCollector {
        onStreamFinished: {
          var v = root.verdict(text);
          root.mounting = root.mark(root.mounting, run.device, false);
          if (v.ok)
            launcher.exec(["xdg-open", v.mountpoint]);
          else
            root.problem("Can't open " + root.name(root.find(run.device) || {}), v.message);
          run.destroy();
        }
      }
    }
  }

  Component {
    id: ejectComponent

    Process {
      id: run

      required property string device
      required property string label

      function start() {
        command = [root.program, "eject", device];
        running = true;
      }

      stdout: StdioCollector {
        onStreamFinished: {
          var v = root.verdict(text);
          root.ejecting = root.mark(root.ejecting, run.device, false);
          if (v.ok) {
            root.ejected(v.name || run.label);
          } else if (v.error === "busy") {
            var who = v.blockers && v.blockers.length > 0 ? "In use by " + v.blockers.join(", ") : "Something is still using it";
            root.problem("Can't eject " + run.label, who);
          } else if (v.error !== "gone") {
            root.problem("Can't eject " + run.label, v.message);
          }
          run.destroy();
        }
      }
    }
  }

  Command {
    id: launcher

    label: "USB open"
  }

  Process {
    id: watcher

    command: [root.program, "watch"]
    running: true

    stdout: SplitParser {
      onRead: data => {
        try {
          root.apply(JSON.parse(data));
        } catch (err) {
          console.warn("island-usb: unreadable line: " + data);
        }
      }
    }

    // udisks may restart, or the program may not be installed yet: try again later.
    onExited: restart.start()
  }

  Timer {
    id: restart

    interval: 10000
    onTriggered: watcher.running = true
  }
}
