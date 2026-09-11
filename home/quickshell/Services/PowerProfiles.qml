pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Power profiles, driven through powerprofilesctl. Nothing notifies on an external
// change, so the daemon is re-read after every write and its answer is the truth.
Singleton {
  id: root

  // The active profile as the daemon spells it; empty until something answers.
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

    // powerprofilesctl returns before the daemon has finished switching.
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

  // The daemon and quickshell come up in either order, so this backs off forever
  // rather than giving up after a fixed number of tries.
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