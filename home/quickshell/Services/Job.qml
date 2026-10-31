import QtQuick
import Quickshell
import qs.Commons

// One piece of work with a beginning and an end that the shell reports: the rebuild
// implements this today. A singleton file takes this as its root type, since Singleton is
// the base here.
Singleton {
  // "" when idle, else running, done or failed. Only the latest run is kept.
  property string phase: ""

  // Steps finished, of `total`; 0 while the total is not known.
  property int done: 0
  property int total: 0

  // Milliseconds since the epoch; endedAt is 0 until the run ends.
  property real startedAt: 0
  property real endedAt: 0

  readonly property bool running: phase === "running"
  readonly property real fraction: total > 0 ? Theme.clamp01(done / total) : 0

  // Stop showing a finished or failed run; what that hides is up to the implementation.
  function dismiss() {
  }
}
