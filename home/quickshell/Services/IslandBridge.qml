pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The socket programs outside the shell report to: Claude Code's hooks (pkgs/claude-island) and
// `rebuild` (pkgs/rebuild). Each connection sends one JSON object a line and hangs up; `src` says
// whom it is from and the service that owns that source takes it from `received`. The socket
// is in the runtime directory, so a hook finds it missing (and does nothing) when the shell is
// not running. A stale file from a shell that died is replaced.
Singleton {
  id: root

  signal received(var msg)

  readonly property string path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-island.sock"

  SocketServer {
    active: true
    path: root.path

    handler: Socket {
      parser: SplitParser {
        onRead: data => {
          var msg;
          try {
            msg = JSON.parse(data);
          } catch (err) {
            return;
          }
          if (msg !== null && typeof msg === "object")
            root.received(msg);
        }
      }
    }
  }
}
