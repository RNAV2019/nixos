pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
  property bool available: false

  // Off is `identity`, which drops the ramp; writing the neutral would leave a slightly
  // warm 6000K ramp. Since 0.4.0 still reports a stale figure, on/off is the shell's own.
  property bool active: false

  // What to restore if a write fails, so a refused command does not leave the tile lying.
  property bool _restore: false

  readonly property bool enabled: available && active

  function set(on) {
    _restore = active;
    active = on;
    apply.command = on ? ["hyprctl", "hyprsunset", "temperature", String(root.warmTemperature)] : ["hyprctl", "hyprsunset", "identity"];
    apply.running = true;
  }

  function toggle() {
    set(!enabled);
  }

  function refresh() {
    if (!query.running)
      query.running = true;
  }

  Process {
    id: apply

    // hyprctl returns before hyprsunset has finished applying.
    onExited: function (code) {
      // Nothing moved on the daemon, so nothing should have moved here.
      if (code !== 0)
        root.active = root._restore;
      settle.restart();
    }
  }

  Timer {
    id: settle

    interval: 120
    onTriggered: root.refresh()
  }

  Process {
    id: query

    command: ["hyprctl", "hyprsunset", "temperature"]

    stdout: StdioCollector {
      onStreamFinished: {
        var value = parseInt(text.trim(), 10);
        if (isNaN(value)) {
          root.available = false;
          return;
        }
        root.available = true;
        root.temperature = value;
        // The read-back can put the state down but never up - a warm figure may be the
        // ramp's ghost - which is how a restarted daemon gets caught.
        if (value >= root.neutralTemperature)
          root.active = false;
      }
    }

    onExited: function (code) {
      if (code !== 0)
        root.available = false;
    }
  }

  // hyprsunset and quickshell come up in either order, so this backs off forever: a fixed
  // try limit left the tile "Unavailable" when hyprsunset started later in the session.
  property int _tries: 0

  readonly property int eagerTries: 15

  Timer {
    running: !root.available
    interval: root._tries < root.eagerTries ? 2000 : 60000
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root._tries++;
      root.refresh();
    }
  }
}
