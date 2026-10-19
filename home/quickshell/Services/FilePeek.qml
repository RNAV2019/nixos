import QtQuick
import Quickshell.Io

// The first lines of a text file, re-read whenever `path` changes; tabs become two spaces.
// An empty path reads nothing.
Process {
  id: root

  property string path: ""
  property int lines: 14
  property int bytes: 2048
  property string text: ""

  command: ["head", "-n", String(lines), "-c", String(bytes), "--", path]

  onPathChanged: {
    text = "";
    running = false;
    if (path !== "")
      running = true;
  }

  stdout: StdioCollector {
    onStreamFinished: root.text = text.replace(/\t/g, "  ")
  }
}
