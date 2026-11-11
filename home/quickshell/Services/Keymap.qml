pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The cheatsheet's lines (Keys/KeysSheet.qml): columns of sections of rows, each row its keycaps
// and what they do. home/desktop.nix writes the file from the binds themselves, so the sheet
// cannot list a key that is not bound.
Singleton {
  id: root

  // QS_KEYS_DATA points at another file, for testing before a rebuild links this one.
  readonly property string dataPath: Quickshell.env("QS_KEYS_DATA") || (Quickshell.env("XDG_DATA_HOME") || Paths.home + "/.local/share") + "/quickshell/keys.json"

  // [[{ title, rows: [{ caps: [string], label }] }]]; empty until the file loads, or if it is
  // missing or malformed.
  property var columns: []

  readonly property bool available: columns.length > 0

  function parse(text) {
    try {
      var data = JSON.parse(text);
      columns = Array.isArray(data.columns) ? data.columns : [];
    } catch (e) {
      console.warn("keymap: " + dataPath + " is not valid JSON: " + e);
      columns = [];
    }
  }

  FileView {
    id: file

    path: root.dataPath
    printErrors: false
    watchChanges: true

    onLoaded: Qt.callLater(function () {
      root.parse(file.text());
    })
    onFileChanged: reload()
  }
}
