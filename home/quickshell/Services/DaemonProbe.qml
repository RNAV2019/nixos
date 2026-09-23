import QtQuick
import Quickshell.Io

// The refresh/settle/backoff/query scaffolding the daemon services shared: the daemon
// answers a question, nothing notifies on an external change, and daemon and shell come
// up in either order.
Item {
  id: root

  // The command that asks the daemon for its state.
  property var command: []

  // text -> value, or null when the answer does not parse; null marks the daemon as not
  // answering.
  property var parse: null

  // The daemon settles late, so a write waits this long before the state is read back.
  property int settleMs: 120

  // Probing backs off forever: eager right after start, then a slow idle poll, so a
  // daemon that appears later in the session is still caught.
  property int eagerTries: 15
  property int eagerMs: 2000
  property int idleMs: 60000

  // A caller that optimistically flips local state bumps this per write; a query launched
  // before the bump reads the daemon mid-write, and its late answer is discarded.
  property int writeSeq: 0

  readonly property bool available: _available
  property var value: null

  // Emitted per accepted answer, for the caller's own read-back logic.
  signal answered(var value)

  property bool _available: false
  property int _tries: 0
  property bool _settleMissed: false

  function refresh() {
    if (!query.running)
      query.running = true;
  }

  // To be called after a write: the daemon is given settleMs, then asked again.
  function settle() {
    settleTimer.restart();
  }

  Timer {
    id: settleTimer

    interval: root.settleMs
    onTriggered: {
      if (query.running) {
        // The read in flight was launched before the write, so its answer would be stale;
        // ask once more when it lands.
        root._settleMissed = true;
        return;
      }
      root.refresh();
    }
  }

  Process {
    id: query

    property int tag: 0

    command: root.command

    onRunningChanged: {
      if (query.running) {
        query.tag = root.writeSeq;
      } else if (root._settleMissed) {
        root._settleMissed = false;
        settleTimer.restart();
      }
    }

    stdout: StdioCollector {
      onStreamFinished: {
        var value = root.parse ? root.parse(text) : null;
        if (value === null || value === undefined) {
          root._available = false;
          return;
        }
        if (query.tag < root.writeSeq)
          return;
        root._available = true;
        root.value = value;
        root.answered(value);
      }
    }

    onExited: function (code) {
      if (code !== 0 && query.tag >= root.writeSeq)
        root._available = false;
    }
  }

  Timer {
    running: !root.available
    interval: root._tries < root.eagerTries ? root.eagerMs : root.idleMs
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root._tries++;
      root.refresh();
    }
  }
}
