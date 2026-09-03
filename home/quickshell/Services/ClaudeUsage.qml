pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Claude subscription rate limits, polled from the OAuth usage endpoint via
// claude-usage(1). A failed poll leaves the last reading on the bar marked
// stale rather than blanking it; claude-usage caches that reading itself, so
// even a fresh shell comes up populated. An unusable token is its own state,
// since only Claude Code can refresh one and retrying will not help.
Singleton {
  id: root

  readonly property int interval: 120000
  // First retry after a failed poll, doubled per failure up to `interval`.
  readonly property int retryInterval: 10000

  // A reading exists, however old. `stale` says the last poll did not land.
  property bool available: false
  property bool stale: false
  property bool expired: false
  property real fiveHour: 0
  property real sevenDay: 0
  property date fiveHourResets: new Date(0)
  property date sevenDayResets: new Date(0)
  property date updated: new Date(0)

  property int failures: 0

  function refresh() {
    if (!fetch.running)
      fetch.running = true;
  }

  // Matches the statusline thresholds: foam under half, gold, then love.
  function severity(percent) {
    if (percent >= 80)
      return Theme.love;
    if (percent >= 50)
      return Theme.gold;
    return Theme.text;
  }

  Process {
    id: fetch

    command: ["claude-usage"]

    stdout: StdioCollector {
      onStreamFinished: {
        var line = text.trim();
        if (line === "")
          return;
        try {
          var d = JSON.parse(line);
          root.fiveHour = d.fiveHour;
          root.sevenDay = d.sevenDay;
          root.fiveHourResets = new Date(d.fiveHourResets * 1000);
          root.sevenDayResets = new Date(d.sevenDayResets * 1000);
          root.updated = new Date((d.updated || 0) * 1000);
          root.expired = d.status === "expired";
          root.stale = d.status !== "ok";
          root.available = true;
          // Only a network-shaped failure is worth hurrying a retry for.
          root.failures = d.status === "stale" ? root.failures + 1 : 0;
        } catch (e) {
          root.stale = true;
          root.failures += 1;
        }
      }
    }

    // Nothing on stdout: no cached reading to fall back on either.
    onExited: function (code) {
      if (code === 0)
        return;
      root.expired = code === 2;
      root.stale = true;
      if (!root.expired)
        root.failures += 1;
    }
  }

  Timer {
    running: true
    repeat: true
    triggeredOnStart: true
    interval: root.failures === 0 ? root.interval : Math.min(root.retryInterval * Math.pow(2, root.failures - 1), root.interval)
    onTriggered: root.refresh()
  }
}
