pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keep `ps` polling idle until a subscriber activates the service.
Singleton {
  id: root

  property int subscribers: 0

  function subscribe() {
    subscribers++;
  }
  function unsubscribe() {
    subscribers = Math.max(0, subscribers - 1);
  }

  readonly property bool active: subscribers > 0

  readonly property int pollInterval: 2000

  // Each entry: { pid, name, cpu, mem }
  property var byCpu: []
  property var byMemory: []

  Process {
    id: ps
    command: ["ps", "-eo", "pid,comm,%cpu,%mem", "--sort=-%cpu", "--no-headers"]
    stdout: StdioCollector {
      onStreamFinished: root._parse(text)
    }
  }

  Timer {
    running: root.active
    repeat: true
    triggeredOnStart: true
    interval: root.pollInterval
    onTriggered: {
      if (!ps.running)
        ps.running = true;
    }
  }

  onActiveChanged: {
    if (!active) {
      byCpu = [];
      byMemory = [];
    }
  }

  function _parse(text) {
    var rows = [];
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/);
      if (f.length < 4)
        continue;
      rows.push({
        pid: parseInt(f[0]),
        name: f[1],
        cpu: parseFloat(f[2]),
        mem: parseFloat(f[3])
      });
    }

    byCpu = rows.slice(0, 5);

    var mem = rows.slice();
    mem.sort(function (a, b) {
      return b.mem - a.mem;
    });
    byMemory = mem.slice(0, 5);
  }
}
