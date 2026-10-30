pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The keybinds the cheatsheet lists. Nix writes them out of the same table that generates the
// Hyprland binds (home/keybinds.nix), so there is no second list to keep in step: the file is
// [ { group, rows: [ { desc, keys: [ cap, ... ] } ] } ], groups in the order they are drawn.
// The shell's own config tree is out of store, so the file sits beside the emoji table.
Singleton {
  id: root

  // QS_BINDINGS points at another file, for testing before a rebuild links this one.
  readonly property string dataPath: Quickshell.env("QS_BINDINGS") || (Quickshell.env("XDG_DATA_HOME") || Paths.home + "/.local/share") + "/quickshell/bindings.json"

  // Empty until the file loads, or if it is missing.
  property var groups: []

  // A group's height on the sheet: its heading band and a row's pitch each, as in the design.
  function groupHeight(group) {
    return Theme.cheatHeadBand + Theme.cheatRowPitch * group.rows.length;
  }

  function columnHeight(columnGroups) {
    var h = 0;
    for (var i = 0; i < columnGroups.length; i++)
      h += groupHeight(columnGroups[i]);
    return h + Theme.cheatGroupGap * Math.max(0, columnGroups.length - 1);
  }

  // The groups in sheet order cut into Theme.cheatColumns runs, the cut that leaves the
  // tallest column shortest: the design's 13/14/13 split falls out of it. Each run is a column.
  readonly property var columns: {
    var count = Theme.cheatColumns;
    var all = groups;
    var best = null;
    var bestHeight = Infinity;
    function cut(from, left, picked) {
      if (left === 1) {
        var last = picked.concat([all.slice(from)]);
        var tallest = 0;
        for (var i = 0; i < last.length; i++)
          tallest = Math.max(tallest, root.columnHeight(last[i]));
        if (tallest < bestHeight) {
          bestHeight = tallest;
          best = last;
        }
        return;
      }
      for (var to = from; to <= all.length; to++)
        cut(to, left - 1, picked.concat([all.slice(from, to)]));
    }
    cut(0, count, []);
    return best || [];
  }

  // The tallest column, which sets the sheet's height.
  readonly property real bodyHeight: {
    var tallest = 0;
    for (var i = 0; i < columns.length; i++)
      tallest = Math.max(tallest, columnHeight(columns[i]));
    return tallest;
  }

  function parse(text) {
    var data;
    try {
      data = JSON.parse(text);
    } catch (e) {
      console.warn("keybinds: " + root.dataPath + " is not valid JSON: " + e);
      return;
    }
    root.groups = Array.isArray(data) ? data : [];
  }

  FileView {
    id: file

    path: root.dataPath
    printErrors: false
    watchChanges: true

    onLoaded: root.parse(file.text())
    onFileChanged: reload()
  }
}
