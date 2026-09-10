pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Power profiles, driven through powerprofilesctl.
//
// power-profiles-daemon owns the platform's performance stance; this only
// tells it which of its three profiles to hold. There is no notification when
// something else changes the profile - tlp, a GNOME neighbour or a script can
// all write it - so the service asks for the current one on startup and after
// every write, and takes the daemon's answer as the truth rather than its own
// last command.
//
// If the daemon is not running the calls fail harmlessly and `available` goes
// false, which is what greys the card's tiles out rather than leaving a
// picker that does nothing.
Singleton {
  id: root

  // The active profile as the daemon spells it: "performance", "balanced" or
  // "power-saver". Empty while nothing has answered yet.
  property string profile: ""

  property bool available: false

  function refresh() {
    if (!query.running)
      query.running = true;
  }

  function set(name) {
    if (name === root.profile)
      return;
    apply.command = ["powerprofilesctl", "set", name];
    apply.running = true;
  }

  Process {
    id: apply

    // powerprofilesctl returns before the daemon has finished switching, so
    // the read-back is a beat behind the write rather than part of it.
    onExited: settle.restart()
  }

  Timer {
    id: settle

    interval: 120
    onTriggered: root.refresh()
  }

  Process {
    id: query

    command: ["powerprofilesctl", "get"]

    stdout: StdioCollector {
      onStreamFinished: {
        var value = text.trim();
        if (value === "") {
          root.available = false;
          return;
        }
        root.available = true;
        root.profile = value;
      }
    }

    onExited: function (code) {
      if (code !== 0)
        root.available = false;
    }
  }

  // The daemon and quickshell come up together and in either order, so the
  // first read can beat it to the bus. This backs off rather than giving up:
  // a run of quick attempts to catch a daemon that is only a moment behind,
  // then a minute apart forever. Stopping after a fixed number of tries is
  // what left a tile reading "Unavailable" for the rest of a session in which
  // the daemon was installed and started afterwards.
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