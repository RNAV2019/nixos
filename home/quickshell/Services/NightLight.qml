pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light, driven through hyprsunset.
//
// hyprsunset owns the colour ramp; this only tells it which of two states to be
// in. There is no notification when something else changes the temperature, so
// the service asks for the current one on startup and after every write, and
// takes hyprsunset's answer as the truth rather than its own last command.
//
// The daemon is a user unit started with the session. If it is not running the
// calls fail harmlessly and `available` goes false, which is what greys the
// tile out rather than leaving a toggle that does nothing.
Singleton {
  id: root

  // Warm enough to read as an evening screen without tinting whites orange.
  readonly property int warmTemperature: 4000

  // hyprsunset's own neutral, and what it reports back after `identity`: it
  // answers 6000, not the 6500 the daylight figure would suggest. Reading the
  // state off a threshold above its neutral would call an untouched screen
  // warm, which is how the tile came to say it was on when nothing had asked
  // for it.
  readonly property int neutralTemperature: 6000

  property int temperature: neutralTemperature
  property bool available: false

  readonly property bool enabled: available && temperature > 0 && temperature < neutralTemperature

  // Off is written as the neutral temperature, not as `identity`. Both clear
  // the tint, but `identity` leaves the daemon still reporting the warm figure
  // it was last given - `temperature 4000`, `identity`, `temperature` answers
  // 4000 - and this service takes that answer as the state. Turning the tile
  // off with `identity` would therefore leave it lit and claiming 4000K over a
  // screen that had already gone neutral.
  function set(on) {
    apply.command = ["hyprctl", "hyprsunset", "temperature", String(on ? root.warmTemperature : root.neutralTemperature)];
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
    onExited: settle.restart()
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
