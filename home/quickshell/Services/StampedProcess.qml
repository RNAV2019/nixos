import QtQuick
import Quickshell.Io

// A process whose answer is only good while the question is the one it was asked: `stamp` is
// what the caller wants now, and each run keeps the stamp it started under, so an answer
// that lands after the question moved on can be told from a current one and dropped.
Process {
  id: root

  // The question as it stands: a path, an expression, a write counter.
  property var stamp: null
  property var launchedFor: null

  // The run in flight, or the last one, was started for a question since replaced.
  readonly property bool stale: launchedFor !== stamp

  onRunningChanged: {
    if (running)
      launchedFor = stamp;
  }
}
