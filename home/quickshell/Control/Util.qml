pragma Singleton

import QtQuick
import Quickshell

// Small pure helpers shared by the control centre's views.
Singleton {
  // Collects the values for which predicate is true, preserving order.
  function filterDevices(values, predicate) {
    var out = [];
    for (var i = 0; i < values.length; i++) {
      if (predicate(values[i]))
        out.push(values[i]);
    }
    return out;
  }
}
