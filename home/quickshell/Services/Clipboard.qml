pragma Singleton

import QtQuick
import Quickshell

// Copies go through wl-copy so cliphist records them like any other copy.
Singleton {
  function copy(text) {
    Quickshell.execDetached(["wl-copy", "--", text]);
  }
}
