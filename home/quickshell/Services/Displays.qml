pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons

// Where the external monitor sits relative to the laptop panel. A placement is saved per
// monitor, keyed on its description (make, model and serial), as an offset from the panel,
// and re-applied whenever that monitor connects or Hyprland reloads its config: the Nix
// rules put every output back at `auto` on reload.
Singleton {
  id: root

  readonly property var monitors: Hyprland.monitors.values
  readonly property int count: monitors.length

  readonly property var internal: {
    for (var i = 0; i < monitors.length; i++)
      if (isInternal(monitors[i]))
        return monitors[i];
    return null;
  }

  // Only one external monitor is ever connected, so the first is the one.
  readonly property var external: {
    for (var i = 0; i < monitors.length; i++)
      if (!isInternal(monitors[i]))
        return monitors[i];
    return null;
  }

  // description -> { x, y }, an offset from the laptop panel's origin in layout pixels.
  property var saved: ({})

  function isInternal(m) {
    return m !== null && m.name.indexOf("eDP") === 0;
  }

  // The size the monitor takes up in the layout: its mode over its scale, turned with it.
  function layoutRect(m) {
    var ipc = m.lastIpcObject || {};
    var turned = (ipc.transform || 0) % 2 === 1;
    var w = Math.round((turned ? m.height : m.width) / m.scale);
    var h = Math.round((turned ? m.width : m.height) / m.scale);
    return {
      x: m.x,
      y: m.y,
      w: w,
      h: h
    };
  }

  function refreshRate(m) {
    var ipc = m.lastIpcObject || {};
    return ipc.refreshRate || 0;
  }

  // "ASUSTek COMPUTER INC" reads as ASUS; anything else keeps its first word.
  function makeOf(m) {
    var make = (m.lastIpcObject || {}).make || "";
    if (make.indexOf("ASUSTek") === 0)
      return "ASUS";
    return make.split(" ")[0];
  }

  function modelOf(m) {
    return (m.lastIpcObject || {}).model || m.name;
  }

  function hasSaved(m) {
    return m !== null && saved[m.description] !== undefined;
  }

  // The rule names the monitor by description, so it follows this monitor to any port and
  // replaces the Nix rule of the same name. Mode and scale are restated from the live
  // monitor, since a rule that is new at runtime would otherwise fall back to auto.
  function apply(m, x, y) {
    var rate = refreshRate(m);
    var fields = ["output = " + JSON.stringify("desc:" + m.description), "position = \"" + Math.round(x) + "x" + Math.round(y) + "\""];
    if (rate > 0) {
      fields.push("mode = \"" + m.width + "x" + m.height + "@" + rate.toFixed(2) + "\"");
      fields.push("scale = " + m.scale);
    }
    Quickshell.execDetached(["hyprctl", "eval", "hl.monitor({ " + fields.join(", ") + " })"]);
    settle.restart();
  }

  function place(m, x, y) {
    if (!m || !internal)
      return;
    var next = Object.assign({}, saved);
    next[m.description] = {
      x: Math.round(x - internal.x),
      y: Math.round(y - internal.y)
    };
    saved = next;
    store.setText(JSON.stringify(saved, null, 2));
    apply(m, x, y);
  }

  // Back to Hyprland's own default: right of the panel, top edges level.
  function reset(m) {
    if (!m || !internal)
      return;
    var next = Object.assign({}, saved);
    delete next[m.description];
    saved = next;
    store.setText(JSON.stringify(saved, null, 2));
    var panel = layoutRect(internal);
    apply(m, panel.x + panel.w, panel.y);
  }

  function restoreAll() {
    if (!internal)
      return;
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i];
      var offset = isInternal(m) ? undefined : saved[m.description];
      if (offset === undefined)
        continue;
      var x = internal.x + offset.x, y = internal.y + offset.y;
      if (m.x !== x || m.y !== y)
        apply(m, x, y);
    }
  }

  FileView {
    id: store

    path: Paths.stateDir + "/displays.json"
    printErrors: false

    onLoaded: {
      try {
        root.saved = JSON.parse(store.text()) || {};
      } catch (e) {
        root.saved = {};
      }
      root.restoreAll();
    }
  }

  // Quickshell learns a new monitor's mode and description a beat after the event, so the
  // list is refreshed first and the placement applied once it has landed.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "monitoraddedv2" || event.name === "configreloaded")
        reapply.restart();
    }
  }

  Timer {
    id: reapply

    interval: 250
    onTriggered: {
      Hyprland.refreshMonitors();
      restore.restart();
    }
  }

  Timer {
    id: restore

    interval: 250
    onTriggered: root.restoreAll()
  }

  // Hyprland does not announce a moved monitor, so the panel asks for positions once it has.
  Timer {
    id: settle

    interval: 200
    onTriggered: Hyprland.refreshMonitors()
  }
}
