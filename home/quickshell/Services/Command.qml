import QtQuick
import Quickshell.Io

// A one-shot command whose failure is reported rather than swallowed: stderr is kept, and a
// non-zero exit is logged with it and raised as `failed`, so callers can show it too.
Process {
  id: root

  // What the command is for, in the log line ("Wi-Fi disconnect"); the binary by default.
  property string label: command.length > 0 ? command[0] : ""
  property string errText: ""
  property int exitCode: 0
  // Off where the caller already logs the failure in its own words.
  property bool logFailures: true

  signal failed(int code, string message)

  // Starts `args` unless a run is still going, which it would clobber. Returns whether it ran.
  function exec(args) {
    if (root.running) {
      console.warn(root.label + ": still running, request dropped");
      return false;
    }
    root.errText = "";
    root.command = args;
    root.running = true;
    return true;
  }

  stderr: StdioCollector {
    onStreamFinished: root.errText = text.trim()
  }

  onExited: function (code) {
    root.exitCode = code;
    if (code === 0)
      return;
    if (root.logFailures)
      console.warn(root.label + " failed (" + code + ")" + (root.errText !== "" ? ": " + root.errText : ""));
    root.failed(code, root.errText);
  }
}
