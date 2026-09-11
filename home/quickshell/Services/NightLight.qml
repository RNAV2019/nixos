pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light, driven through hyprsunset.
//
// hyprsunset owns the colour ramp; this only tells it which of two states to be in.
// Nothing notifies when something else changes the temperature, so the daemon is asked
// on startup and after every write. If it is not running the calls fail harmlessly and
// `available` goes false, which greys the tile out.
Singleton {
  id: root

  // Deep amber, close to candlelight.
  readonly property int warmTemperature: 4500

  // hyprsunset's own neutral, and what it reports after `identity`: it answers 6000, not
  // the 6500 daylight would suggest. Reading state off a threshold above its neutral
  // would call an untouched screen warm.
  readonly property int neutralTemperature: 6000

  property int temperature: neutralTemperature
  property bool available: false

  // Off is written as `identity`, which drops the ramp entirely. Writing the neutral
  // temperature instead leaves hyprsunset driving a 6000K ramp that is slightly warm.
  //
  // The cost is that hyprsunset cannot then be asked whether its ramp is up: against
  // 0.4.0, `temperature` still answers the last figure set long after `identity` dropped
  // the ramp. So the on/off state is the shell's own, and this is it.
  property bool active: false

  // What to go back to if a write fails, so a refused command does not leave the tile
  // claiming it happened.
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
        // The read-back can never put the state up - a warm figure may be the ramp or its
        // ghost - but it can put it down, which is how a restarted daemon gets caught.
        if (value >= root.neutralTemperature)
          root.active = false;
      }
    }

    onExited: function (code) {
      if (code !== 0)
        root.available = false;
    }
  }

  // hyprsunset and quickshell come up in either order, so this backs off forever rather
  // than giving up: stopping after a fixed number of tries left the tile reading
  // "Unavailable" for the rest of a session in which hyprsunset was started afterwards.
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
