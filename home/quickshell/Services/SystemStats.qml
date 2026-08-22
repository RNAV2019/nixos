pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Read /proc and /sys directly. Subscribers use the fast polling interval;
// otherwise polling drops to the idle interval.
Singleton {
  id: root

  readonly property int fastInterval: 1000
  readonly property int idleInterval: 5000

  property int subscribers: 0

  function subscribe() {
    subscribers++;
  }
  function unsubscribe() {
    subscribers = Math.max(0, subscribers - 1);
  }

  // Aggregate usage, 0..1.
  property real cpuUsage: 0
  // Per-core usage, 0..1, in /proc/stat order.
  property var coreUsage: []

  property var _prevTotals: []
  property var _prevIdles: []

  property real memoryUsage: 0      // 0..1
  property real memoryUsedKb: 0
  property real memoryTotalKb: 0
  property real swapUsage: 0        // 0..1
  property real swapUsedKb: 0
  property real swapTotalKb: 0

  property real load1: 0
  property real load5: 0
  property real load15: 0
  property real uptimeSeconds: 0

  // Find the sensor by name because hwmon numbering changes across boots.
  property string tempPath: ""
  property real cpuTemp: 0

  function formatUptime() {
    var s = Math.floor(uptimeSeconds);
    var d = Math.floor(s / 86400);
    var h = Math.floor((s % 86400) / 3600);
    var m = Math.floor((s % 3600) / 60);
    if (d > 0)
      return d + "d " + h + "h " + m + "m";
    if (h > 0)
      return h + "h " + m + "m";
    return m + "m";
  }

  function formatKb(kb) {
    if (kb >= 1048576)
      return (kb / 1048576).toFixed(1) + " GiB";
    if (kb >= 1024)
      return (kb / 1024).toFixed(0) + " MiB";
    return kb + " KiB";
  }

  Process {
    id: findTemp
    running: true
    command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in k10temp|coretemp|zenpower) echo \"$d/temp1_input\"; exit 0;; esac; done"]
    stdout: StdioCollector {
      onStreamFinished: root.tempPath = text.trim()
    }
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    onLoaded: root._parseStat(statFile.text())
  }

  FileView {
    id: memFile
    path: "/proc/meminfo"
    onLoaded: root._parseMeminfo(memFile.text())
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    onLoaded: root._parseLoadavg(loadFile.text())
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    onLoaded: root.uptimeSeconds = parseFloat(uptimeFile.text().split(" ")[0]) || 0
  }

  FileView {
    id: tempFile
    path: root.tempPath
    onLoaded: root.cpuTemp = (parseFloat(tempFile.text()) || 0) / 1000
  }

  Timer {
    running: true
    repeat: true
    triggeredOnStart: true
    interval: root.subscribers > 0 ? root.fastInterval : root.idleInterval
    onTriggered: {
      statFile.reload();
      memFile.reload();
      loadFile.reload();
      uptimeFile.reload();
      if (root.tempPath !== "")
        tempFile.reload();
    }
  }

  // CPU usage uses sample deltas, so the first sample reports 0.
  function _parseStat(text) {
    var lines = text.split("\n");
    var totals = [];
    var idles = [];

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].indexOf("cpu") !== 0)
        break;
      var f = lines[i].trim().split(/\s+/);
      var total = 0;
      for (var j = 1; j < f.length; j++)
        total += parseInt(f[j]) || 0;
      // fields: user nice system idle iowait ...
      var idle = (parseInt(f[4]) || 0) + (parseInt(f[5]) || 0);
      totals.push(total);
      idles.push(idle);
    }

    if (_prevTotals.length === totals.length) {
      var usage = [];
      for (var k = 0; k < totals.length; k++) {
        var dTotal = totals[k] - _prevTotals[k];
        var dIdle = idles[k] - _prevIdles[k];
        usage.push(dTotal > 0 ? Math.max(0, Math.min(1, 1 - dIdle / dTotal)) : 0);
      }
      cpuUsage = usage[0];
      coreUsage = usage.slice(1);
    }

    _prevTotals = totals;
    _prevIdles = idles;
  }

  function _parseMeminfo(text) {
    var v = {};
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^(\w+):\s+(\d+)/);
      if (m)
        v[m[1]] = parseInt(m[2]);
    }
    memoryTotalKb = v.MemTotal || 0;
    memoryUsedKb = memoryTotalKb - (v.MemAvailable || 0);
    memoryUsage = memoryTotalKb > 0 ? memoryUsedKb / memoryTotalKb : 0;

    swapTotalKb = v.SwapTotal || 0;
    swapUsedKb = swapTotalKb - (v.SwapFree || 0);
    swapUsage = swapTotalKb > 0 ? swapUsedKb / swapTotalKb : 0;
  }

  function _parseLoadavg(text) {
    var f = text.trim().split(/\s+/);
    load1 = parseFloat(f[0]) || 0;
    load5 = parseFloat(f[1]) || 0;
    load15 = parseFloat(f[2]) || 0;
  }
}
