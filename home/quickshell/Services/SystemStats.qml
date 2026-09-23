pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU and memory load, read from procfs every couple of seconds for the island's gauge.
Singleton {
  id: root

  // Both 0..1.
  property real cpu: 0
  property real memory: 0

  // /proc/stat is cumulative, so CPU load is the busy share of ticks since the previous read.
  property real _lastIdle: -1
  property real _lastTotal: 0

  readonly property int interval: 2000

  function readCpu(text) {
    var fields = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
    if (fields.length < 5)
      return;
    // idle plus iowait
    var idle = fields[3] + fields[4];
    var total = 0;
    for (var i = 0; i < fields.length && i < 8; i++)
      total += fields[i];
    if (root._lastIdle >= 0 && total > root._lastTotal) {
      var busy = 1 - (idle - root._lastIdle) / (total - root._lastTotal);
      root.cpu = Math.max(0, Math.min(1, busy));
    }
    root._lastIdle = idle;
    root._lastTotal = total;
  }

  function readMemory(text) {
    var total = 0;
    var available = 0;
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^(MemTotal|MemAvailable):\s+(\d+)/);
      if (!m)
        continue;
      if (m[1] === "MemTotal")
        total = Number(m[2]);
      else
        available = Number(m[2]);
    }
    if (total > 0)
      root.memory = Math.max(0, Math.min(1, 1 - available / total));
  }

  FileView {
    id: stat

    path: "/proc/stat"
    onLoaded: root.readCpu(text())
  }

  FileView {
    id: meminfo

    path: "/proc/meminfo"
    onLoaded: root.readMemory(text())
  }

  Timer {
    interval: root.interval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      stat.reload();
      meminfo.reload();
    }
  }
}
