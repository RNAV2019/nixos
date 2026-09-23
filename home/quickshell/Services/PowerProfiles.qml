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

  property bool available: probe.available

  function refresh() {
    probe.refresh();
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
    onExited: probe.settle()
  }

  DaemonProbe {
    id: probe

    command: ["powerprofilesctl", "get"]

    parse: function (text) {
      var value = text.trim();
      return value === "" ? null : value;
    }

    onAnswered: function (value) {
      root.profile = value;
    }
  }
}
