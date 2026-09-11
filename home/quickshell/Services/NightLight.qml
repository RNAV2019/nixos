pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light, driven through hyprsunset.
//
// hyprsunset owns the colour ramp; this only tells it which of two states to be
// in. There is no notification when something else changes the temperature, so
// the service asks for the current one on startup and after every write. That
// answer carries the figure, and says whether the daemon is there at all, but
// it cannot say whether the ramp is actually up - see `active` below, which is
// why the on/off state is the shell's own.
//
// The daemon is a user unit started with the session. If it is not running the
// calls fail harmlessly and `available` goes false, which is what greys the
// tile out rather than leaving a toggle that does nothing.
Singleton {
  id: root

  // Deep amber, close to candlelight: a proper evening screen rather than a
  // hint of warmth.
  readonly property int warmTemperature: 4500

  // hyprsunset's own neutral, and what it reports back after `identity`: it
  // answers 6000, not the 6500 the daylight figure would suggest. Reading the
  // state off a threshold above its neutral would call an untouched screen
  // warm, which is how the tile came to say it was on when nothing had asked
  // for it.
  readonly property int neutralTemperature: 6000

  property int temperature: neutralTemperature
  property bool available: false

  // Off is written as `identity`, which drops the ramp entirely - the same
  // neutral a killed daemon leaves behind. Writing the neutral temperature
  // instead would keep hyprsunset driving a 6000K ramp, which through its own
  // conversion is slightly warm and never quite matched that neutral.
  //
  // The cost is that hyprsunset cannot then be asked whether its ramp is up.
  // `temperature` answers with the last figure a `temperature` command set, and
  // goes on answering it after `identity` has dropped the ramp: against
  // hyprsunset 0.4.0, `identity` and then `temperature` answers 4500 over a
  // screen that has already gone neutral, and there is no second verb that
  // tells the two apart. A screen that has been warm once reports warm for the
  // rest of the session.
  //
  // So the on/off state is the shell's own, and this is it. Deriving it from
  // the read-back is what left the tile lit with the night light off: the off
  // write set the state right for a moment, and the next refresh - the control
  // centre fires one every time it opens - read the stale figure and put it
  // straight back.
  property bool active: false

  // What to go back to if a write fails, so a command the daemon refused does
  // not leave the tile claiming it happened.
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

    // hyprctl returns before hyprsunset has finished applying, so the read-back
    // is a beat behind the write rather than part of it.
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
        // The read-back can never put the state up - a warm figure may be the
        // ramp or may be its ghost - but it can put it down. A daemon
        // answering its own neutral has not been asked for anything warm,
        // which is how a restart of hyprsunset under a shell that thinks the
        // night light is on gets caught.
        if (value >= root.neutralTemperature)
          root.active = false;
      }
    }

    onExited: function (code) {
      if (code !== 0)
        root.available = false;
    }
  }

  // hyprsunset and quickshell come up together and in either order, so the
  // first read can beat the daemon to the socket. This backs off rather than
  // giving up: a run of quick attempts to catch a daemon that is only a moment
  // behind, then a minute apart forever.
  //
  // It has to be forever. Stopping after a fixed number of tries is what left
  // the tile reading "Unavailable" for the rest of a session in which
  // hyprsunset was installed and started afterwards - it had spent its
  // attempts before there was anything to answer them, and nothing ever asked
  // again.
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
