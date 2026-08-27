pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Claude subscription rate limits, polled from the OAuth usage endpoint via
// claude-usage(1). Values stay at the last good reading while a poll fails so
// a blip of no network does not blank the bar.
Singleton {
  id: root

  readonly property int interval: 120000

  property bool available: false
  property real fiveHour: 0
  property real sevenDay: 0
  property date fiveHourResets: new Date(0)
  property date sevenDayResets: new Date(0)

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
          root.available = true;
        } catch (e) {
          root.available = false;
        }
      }
    }

    // Logged out, token expired, or the request failed.
    onExited: function (code) {
      if (code !== 0)
        root.available = false;
    }
  }

  Timer {
    running: true
    repeat: true
    triggeredOnStart: true
    interval: root.interval
    onTriggered: root.refresh()
  }
}
