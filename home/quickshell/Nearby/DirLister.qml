import QtQuick
import Quickshell.Io
import qs.Services

// One directory's listing for the file picker: a single `find` for the entries and a second
// pass that counts each folder's own entries, which is the number board 16b shows beside a
// folder. Links are followed, so a folder reached through a symlink lists like any other.
Item {
  id: root

  // The directory to list; an empty path lists nothing.
  property string path: ""
  property bool showHidden: false
  // Only folders, for the parent column.
  property bool dirsOnly: false

  // [{ name, path, dir, size }] - folders first, then files, each in natural order. `size` is
  // bytes for a file and the entry count for a folder.
  property var entries: []
  property bool loading: false
  property string error: ""

  // Raised once a listing for the current path has landed.
  signal loaded

  property var raw: []

  function reload() {
    if (path === "") {
      raw = [];
      entries = [];
      return;
    }
    loading = true;
    error = "";
    lister.running = false;
    lister.command = ["sh", "-c", "cd -- \"$1\" 2>/dev/null || { echo '!'; exit 0; }; " + "find -L . -mindepth 1 -maxdepth 1 -printf '%y\\t%s\\t%f\\n' 2>/dev/null; echo '--'; " + "find -L . -mindepth 2 -maxdepth 2 -not -name '.*' -printf '%h\\n' 2>/dev/null | sort | uniq -c", "sh", path];
    lister.running = true;
  }

  function rebuild() {
    var out = [];
    for (var i = 0; i < raw.length; i++) {
      var e = raw[i];
      if (!showHidden && e.name.charAt(0) === ".")
        continue;
      if (dirsOnly && !e.dir)
        continue;
      out.push(e);
    }
    out.sort(function (a, b) {
      if (a.dir !== b.dir)
        return a.dir ? -1 : 1;
      return a.name.localeCompare(b.name, undefined, {
        "numeric": true,
        "sensitivity": "base"
      });
    });
    entries = out;
  }

  onPathChanged: reload()
  onShowHiddenChanged: rebuild()
  onDirsOnlyChanged: rebuild()
  Component.onCompleted: reload()

  Process {
    id: lister

    // The path this run lists, so a late answer for a folder already left is dropped.
    property string forPath: ""

    onRunningChanged: if (running)
      forPath = root.path

    stdout: StdioCollector {
      onStreamFinished: {
        if (lister.forPath !== root.path)
          return;
        var lines = text.split("\n");
        if (lines.length > 0 && lines[0] === "!") {
          root.raw = [];
          root.error = "Can't open this folder";
          root.loading = false;
          root.rebuild();
          root.loaded();
          return;
        }
        var base = root.path === "/" ? "" : root.path;
        var list = [];
        var counts = {};
        var inCounts = false;
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i];
          if (line === "")
            continue;
          if (line === "--") {
            inCounts = true;
            continue;
          }
          if (inCounts) {
            // "      5 ./papers"
            var m = line.match(/^\s*(\d+)\s+\.\/(.*)$/);
            if (m)
              counts[m[2]] = parseInt(m[1], 10);
            continue;
          }
          var parts = line.split("\t");
          if (parts.length < 3)
            continue;
          var name = parts.slice(2).join("\t");
          list.push({
            "name": name,
            "path": base + "/" + name,
            "dir": parts[0] === "d",
            "size": parseInt(parts[1], 10) || 0
          });
        }
        for (var j = 0; j < list.length; j++) {
          if (list[j].dir)
            list[j].size = counts[list[j].name] !== undefined ? counts[list[j].name] : 0;
        }
        root.raw = list;
        root.loading = false;
        root.rebuild();
        root.loaded();
      }
    }
  }
}
