import QtQuick
import Quickshell.Io

// An image's pixel size, read whenever `path` changes; 0 × 0 until known or for no path.
// `identify` would need ImageMagick; the file header is enough for JPEG/PNG, so this asks
// `file`, which every system has.
Process {
  id: root

  property string path: ""
  property int w: 0
  property int h: 0

  command: ["file", "-bL", "--", path]

  onPathChanged: {
    w = 0;
    h = 0;
    running = false;
    if (path !== "")
      running = true;
  }

  stdout: StdioCollector {
    onStreamFinished: {
      var m = text.match(/(\d+)\s*x\s*(\d+)/g);
      if (!m || m.length === 0)
        return;
      var last = m[m.length - 1].match(/(\d+)\s*x\s*(\d+)/);
      root.w = parseInt(last[1], 10);
      root.h = parseInt(last[2], 10);
    }
  }
}
