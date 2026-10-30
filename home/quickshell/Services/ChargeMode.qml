pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The battery's charge mode, from the kernel's power-supply `charge_types`: it reads
// `[Fast] Standard Long_Life`, the bracketed word being the active one, and writing a word
// selects it. Long_Life is the firmware's conservation mode (it stops near 80%); Fast and
// Long_Life are mutually exclusive, so the file is the only state there is. The file is
// group-writable through a udev rule (hosts/<host>/platform.nix).
Singleton {
  id: root

  // For tests only: QUICKSHELL_CHARGE_TYPES points at a stand-in for the sysfs file.
  readonly property string path: Quickshell.env("QUICKSHELL_CHARGE_TYPES") || "/sys/class/power_supply/BAT0/charge_types"

  // The order a press steps through, and the words the kernel uses.
  readonly property var order: ["Fast", "Standard", "Long_Life"]

  // The active kernel word, "" until the file has been read.
  property string mode: ""
  // The words this machine accepts, in kernel order.
  property var modes: []

  readonly property bool available: mode !== "" && modes.length > 1

  // "Long_Life" -> "Long life"
  readonly property string label: mode.replace("_", " ").replace(/^(.)(.*)$/, function (m, a, b) {
    return a + b.toLowerCase();
  })

  // The lit state: the only mode that limits the charge rather than just pacing it.
  readonly property bool limiting: mode === "Long_Life"

  // The word a press moves to: the next in `order` that the machine offers.
  readonly property string next: {
    var from = order.indexOf(mode);
    for (var i = 1; i <= order.length; i++) {
      var candidate = order[(from + i) % order.length];
      if (modes.indexOf(candidate) >= 0)
        return candidate;
    }
    return mode;
  }

  // The choice made here, kept so a firmware that forgets it across a reboot is put right
  // when the shell next starts. Changes made elsewhere are not saved: they may be exactly
  // the reset being undone.
  property string _wanted: ""
  property bool _wantedLoaded: false
  property bool _restored: false

  // Mode to fall back on if a write is refused, so the tile does not claim a mode it lacks.
  property string _restore: ""

  function set(word) {
    if (!available || word === mode || modes.indexOf(word) < 0)
      return;
    _restore = mode;
    mode = word;
    _wanted = word;
    savedState.setText(word);
    write.exec(["sh", "-c", 'printf %s "$1" > "$2"', "sh", word, root.path]);
  }

  function cycle() {
    set(next);
  }

  function refresh() {
    file.reload();
  }

  // "[Fast] Standard Long_Life" -> modes, and the bracketed one.
  function parse(text) {
    var words = text.trim().split(/\s+/);
    var found = [];
    var active = "";
    for (var i = 0; i < words.length; i++) {
      var w = words[i];
      if (w.charAt(0) === "[" && w.charAt(w.length - 1) === "]") {
        w = w.slice(1, -1);
        active = w;
      }
      if (w !== "")
        found.push(w);
    }
    return {
      modes: found,
      active: active
    };
  }

  // Once both the device and the saved choice are known, undo a reset - once.
  function restore() {
    if (_restored || !_wantedLoaded || mode === "")
      return;
    _restored = true;
    if (_wanted !== "" && _wanted !== mode && modes.indexOf(_wanted) >= 0)
      set(_wanted);
  }

  FileView {
    id: file

    path: root.path
    printErrors: false

    onLoaded: {
      var read = root.parse(file.text());
      // Nothing bracketed is not a reading; keep what is known until the next one.
      if (read.active === "")
        return;
      root.modes = read.modes;
      // A write in flight owns the state; its exit settles it.
      if (!write.running)
        root.mode = read.active;
      root.restore();
    }

    // Absent on a machine without the driver: nothing to show.
    onLoadFailed: {
      root.mode = "";
      root.modes = [];
    }
  }

  FileView {
    id: savedState

    path: Paths.stateDir + "/chargemode"
    printErrors: false

    onLoaded: {
      if (root._wanted === "")
        root._wanted = savedState.text().trim();
      root._wantedLoaded = true;
      root.restore();
    }

    onLoadFailed: {
      root._wantedLoaded = true;
      root.restore();
    }
  }

  // Sysfs sends no inotify events, and the mode changes from other tools too.
  Timer {
    running: true
    interval: 5000
    repeat: true
    onTriggered: file.reload()
  }

  Command {
    id: write

    label: "Charge mode"

    // Nothing moved, so show what the file still says.
    onFailed: root.mode = root._restore
  }

  Connections {
    target: write

    function onExited() {
      file.reload();
    }
  }
}
