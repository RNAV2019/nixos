import QtQuick
import Quickshell.Io

// Turns chosen paths into the files they stand for, with sizes: a file is itself, a folder
// is every non-hidden file under it (links followed, at most 500 per folder), and a path that
// no longer exists is dropped. One expansion at a time; a new one replaces any in flight.
Process {
  id: root

  // [{ path, size }] for the latest expansion, in the order found.
  signal expanded(var entries)

  function expand(paths) {
    running = false;
    command = ["sh", "-c", "for p; do if [ -d \"$p\" ]; then find -L \"$p\" -type f -not -path '*/.*' -printf '%s\\t%p\\n' 2>/dev/null | head -n 500; elif [ -e \"$p\" ]; then stat -L --printf '%s\\t%n\\n' -- \"$p\"; fi; done", "sh"].concat(paths);
    running = true;
  }

  stdout: StdioCollector {
    onStreamFinished: {
      var entries = [];
      var lines = text.split("\n");
      for (var i = 0; i < lines.length; i++) {
        var tab = lines[i].indexOf("\t");
        if (tab < 0)
          continue;
        entries.push({
          "path": lines[i].substring(tab + 1),
          "size": parseInt(lines[i].substring(0, tab), 10) || 0
        });
      }
      root.expanded(entries);
    }
  }
}
