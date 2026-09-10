pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light, driven through hyprsunset.
//
// hyprsunset owns the colour ramp; this only tells it which of two states to be
// in. There is no notification when something else changes the temperature, so
// the service asks for the current one on startup and after every write, and
// takes hyprsunset's answer as the truth rather than its own last command -
// with one exception, noted further down, where the answer is known to be
// stale.
//
// The daemon is a user unit started with the session. If it is not running the
// calls fail harmlessly and `available` goes false, which is what greys the
// tile out rather than leaving a toggle that does nothing.
Singleton {
  id: root

  // Deep amber, close to candlelight: a proper evening screen rather than a
  // hint of warmth.
  readonly property int warmTemperature: 2500

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
  // The cost is that hyprsunset's reported temperature goes stale: it answers
  // with the last figure a `temperature` command set, so `temperature 4000`,
  // `identity`, `temperature` answers 4000 over a screen that has already gone
  // neutral. The read-back that follows an off write is therefore not trusted:
  // this flag marks it, and the state just written is taken as the truth
  // instead. Anything asked for after that is read back as before.
  property bool _identityPending: false

  readonly property bool enabled: available && temperature > 0 && temperature < neutralTemperature

  function set(on) {
    _identityPending = !on;
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
      // A failed write leaves no identity for the read-back to follow, so the
      // next answer is trustworthy again.
      if (code !== 0)
        root._identityPending = false;
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
        if (root._identityPending) {
          // The figure hyprsunset reports survived the identity; the ramp did
          // not. The off just written is the state, not this stale number.
          root._identityPending = false;
          root.temperature = root.neutralTemperature;
          return;
        }
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
