import QtQuick
import Quickshell.Io

// A long-lived stream of lines from a daemon that may not be up yet, or may restart: a
// command's stdout or a unix socket, read a line at a time and started again whenever it
// ends. Name one source; the stream keeps trying until it is up.
Item {
  id: root

  // A command whose stdout is the stream, or the path of a unix socket serving it.
  property var command: []
  property string socketPath: ""

  // The wait before a retry, doubling per failed attempt up to maxRetryMs (equal for a fixed
  // wait). A connection starts the count again.
  property int retryMs: 2000
  property int maxRetryMs: retryMs

  // The source is up: the command is running, or the socket is open.
  readonly property bool connected: root.socketPath !== "" ? socket.connected : process.running

  // The last line the command wrote to stderr: a daemon that is down says so on every retry,
  // which belongs here and not in the log.
  property string errText: ""

  signal line(string text)

  property int _wait: retryMs

  function _connect() {
    if (root.socketPath !== "")
      socket.connected = true;
    else if (root.command.length > 0)
      process.running = true;
  }

  Component.onCompleted: root._connect()

  onConnectedChanged: {
    if (root.connected)
      root._wait = root.retryMs;
  }

  // Each failed attempt can log a warning, so the wait grows while the daemon is away.
  Timer {
    interval: root._wait
    repeat: true
    running: !root.connected
    onTriggered: {
      root._wait = Math.min(root._wait * 2, root.maxRetryMs);
      root._connect();
    }
  }

  Process {
    id: process

    command: root.command

    stdout: SplitParser {
      onRead: data => root.line(data)
    }

    stderr: SplitParser {
      onRead: data => root.errText = data
    }
  }

  Socket {
    id: socket

    path: root.socketPath

    parser: SplitParser {
      onRead: data => root.line(data)
    }
  }
}
