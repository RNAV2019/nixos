pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Night light via hyprsunset, which owns the colour ramp; this only picks the state.
// Nothing notifies external changes, so the daemon is queried after every write.
Singleton {
  id: root

  // Deep amber, close to candlelight.
  readonly property int warmTemperature: 4500

  // hyprsunset's neutral: it reports 6000, not the 6500 daylight suggests. A threshold
  // above its neutral would call an untouched screen warm.
  readonly property int neutralTemperature: 6000

  property int temperature: neutralTemperature
  property bool available: probe.available

  // Off is `identity`, which drops the ramp; writing the neutral would leave a slightly
  // warm 6000K ramp. Since 0.4.0 still reports a stale figure, on/off is the shell's own.
  property bool active: false

  // What to restore if a write fails, so a refused command does not leave the tile lying.
  property bool _restore: false

  // Every write bumps the sequence: a query already in flight reads the daemon mid-ramp,
  // and its late answer must not clobber the optimistic state or the restore above.
  property int _writes: 0

  // Whether a state change has landed since startup, so the saved one does not
  // overwrite a toggle made while the file was still loading.
  property bool _touched: false

  readonly property bool enabled: available && active

  function set(on) {
    _touched = true;
    _restore = active;
    active = on;
    root._writes++;
    apply.command = on ? ["hyprctl", "hyprsunset", "temperature", String(root.warmTemperature)] : ["hyprctl", "hyprsunset", "identity"];
    apply.running = true;
  }

  function toggle() {
    set(!enabled);
  }

  function refresh() {
    probe.refresh();
  }

  // Off and on round-trip a reboot: every change to `active` - a toggle, a refused write
  // reverting, or the probe catching a restarted daemon - is saved, and the saved one is
  // applied once at startup.
  onActiveChanged: savedState.setText(root.active ? "1" : "0")

  FileView {
    id: savedState

    path: Paths.stateDir + "/nightlight"
    printErrors: false

    onLoaded: {
      if (root._touched)
        return;
      if (savedState.text().trim() === "1")
        root.set(true);
    }
  }

  Process {
    id: apply

    // hyprctl returns before hyprsunset has finished applying.
    onExited: function (code) {
      // Nothing moved on the daemon, so nothing should have moved here.
      if (code !== 0)
        root.active = root._restore;
      probe.settle();
    }
  }

  DaemonProbe {
    id: probe

    command: ["hyprctl", "hyprsunset", "temperature"]
    writeSeq: root._writes

    parse: function (text) {
      var value = parseInt(text.trim(), 10);
      return isNaN(value) ? null : value;
    }

    onAnswered: function (value) {
      root.temperature = value;
      // The read-back can put the state down but never up - a warm figure may be the
      // ramp's ghost - which is how a restarted daemon gets caught.
      if (value >= root.neutralTemperature)
        root.active = false;
    }
  }
}
