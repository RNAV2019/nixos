import QtQuick
import Quickshell.Io

// One process in flight; a run asked for while one is going queues exactly one more,
// which starts when the current run exits. A burst of requests therefore collapses
// into a single follow-up instead of a stack of processes.
Process {
  id: root

  property bool queued: false

  function run() {
    if (root.running)
      root.queued = true;
    else
      root.running = true;
  }

  onExited: {
    if (root.queued) {
      root.queued = false;
      Qt.callLater(function () {
        root.running = true;
      });
    }
  }
}
