pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// Burn-in care for the OLED panel: the island pill and the workspaces pill sit in one place for
// hours, so each creeps round a small orbit. The orbit is published on the Bus (pillShift*,
// workspacesOffset*) for the bar and every surface that grows out of the pill.
Singleton {
  id: root

  // For tests only: QUICKSHELL_OLED_SPEEDUP=N runs the orbit N times faster.
  readonly property real speedup: Math.max(1, Number(Quickshell.env("QUICKSHELL_OLED_SPEEDUP")) || 1)

  // Whether any surface, transient, lock or open card is up. The orbit holds still meanwhile, so
  // nothing grows out of a pill that is moving.
  readonly property bool busy: Bus.locking || occupied(Bus.owners) || occupied(Bus.covers) || occupied(Bus.transientScreens) || occupied(Bus.islandCards)

  function occupied(map) {
    for (var k in map)
      return true;
    return false;
  }

  // ---- the orbit ----

  // Counts positions round the ring of points on the square of half-width oledShiftMax; walks
  // between whole numbers are one step of one pixel, which is what travel crosses slowly.
  property real orbitPos: 0

  function ringPoint(i) {
    var m = Theme.oledShiftMax;
    var n = 8 * m;
    var j = ((i % n) + n) % n;
    var side = Math.floor(j / (2 * m));
    var t = j % (2 * m);
    if (side === 0)
      return {
        x: m,
        y: -m + t
      };
    if (side === 1)
      return {
        x: m - t,
        y: m
      };
    if (side === 2)
      return {
        x: -m,
        y: m - t
      };
    return {
      x: -m + t,
      y: -m
    };
  }

  function pointAt(pos) {
    var a = Math.floor(pos);
    var f = pos - a;
    var p = ringPoint(a);
    var q = ringPoint(a + 1);
    return {
      x: p.x + (q.x - p.x) * f,
      y: p.y + (q.y - p.y) * f
    };
  }

  readonly property var islandPoint: pointAt(orbitPos)
  // Half a lap round, so the two never sit on the same side.
  readonly property var workspacesPoint: pointAt(orbitPos + 4 * Theme.oledShiftMax)

  // A step falls due on the timer but waits for the island to be at rest.
  property bool due: false

  function advance() {
    if (!due || busy || travel.running)
      return;
    due = false;
    travel.from = orbitPos;
    travel.to = orbitPos + 1;
    travel.start();
  }

  onBusyChanged: {
    if (travel.running) {
      if (busy)
        travel.pause();
      else
        travel.resume();
    }
    advance();
  }

  Timer {
    interval: Theme.oledShiftInterval / root.speedup
    running: true
    repeat: true
    onTriggered: {
      root.due = true;
      root.advance();
    }
  }

  // Paused rather than stopped when something opens mid-step, so every surface placed against
  // the Bus sees one fixed offset for as long as it is up.
  NumberAnimation {
    id: travel

    target: root
    property: "orbitPos"
    duration: Theme.oledShiftTravel / root.speedup
    easing.type: Easing.Linear
    onRunningChanged: if (!running)
      root.advance()
  }

  Binding {
    target: Bus
    property: "pillShiftX"
    value: root.islandPoint.x
  }

  Binding {
    target: Bus
    property: "pillShiftY"
    value: root.islandPoint.y
  }

  Binding {
    target: Bus
    property: "workspacesOffsetX"
    value: root.workspacesPoint.x
  }

  Binding {
    target: Bus
    property: "workspacesOffsetY"
    value: root.workspacesPoint.y
  }
}
