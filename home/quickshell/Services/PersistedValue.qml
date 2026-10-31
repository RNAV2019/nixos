import QtQuick
import Quickshell.Io
import qs.Commons

// A small value that outlives the shell: text kept in a file under Paths.stateDir, read once
// at startup and written back by every save.
Item {
  id: root

  // The file's name in Paths.stateDir.
  property string name: ""

  // What was saved here last, or the file's text (trimmed) if nothing was saved before it
  // was read.
  property string value: ""

  // The file has been read, or turned out to be absent.
  readonly property bool loaded: _loaded

  // Something has been saved since startup, so a file that is still loading must not
  // overwrite it.
  readonly property bool touched: _touched

  // The file's text, once, when it is read and nothing has been saved before then.
  signal restored(string text)

  property bool _loaded: false
  property bool _touched: false

  function save(text) {
    _touched = true;
    value = text;
    file.setText(text);
  }

  FileView {
    id: file

    path: Paths.stateDir + "/" + root.name
    printErrors: false

    onLoaded: {
      var fresh = !root._touched;
      if (fresh)
        root.value = file.text().trim();
      root._loaded = true;
      if (fresh)
        root.restored(root.value);
    }

    onLoadFailed: root._loaded = true
  }
}
