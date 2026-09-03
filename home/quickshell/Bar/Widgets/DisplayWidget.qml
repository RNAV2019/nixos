import QtQuick
import qs.Commons
import qs.Services

IconWidget {
  id: root

  readonly property var active: Displays.activeMonitors

  glyph: {
    if (active.length === 0)
      return Icons.monitorOff;
    return active.length > 1 ? Icons.monitorMultiple : Icons.monitor;
  }

  // One display fits on a line; more than one gets a count and a line each,
  // so the tooltip stays scannable while docked.
  readonly property string tooltip: {
    if (active.length === 0)
      return "No active display";

    function describe(m) {
      return m.name + "   " + Displays.formatMode(m) + "   " + Math.round(m.scale * 100) + "%";
    }

    if (active.length === 1) {
      var m = active[0];
      return m.name + " · " + Displays.formatMode(m) + " · " + Math.round(m.scale * 100) + "%";
    }

    var lines = [active.length + " displays"];
    for (var i = 0; i < active.length; i++)
      lines.push(describe(active[i]));
    return lines.join("\n");
  }
}
