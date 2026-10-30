pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// What the Overview shows: the workspaces each output carries, the windows on them and their
// geometry, and the few Hyprland actions it takes. The Hyprland objects are normalised here so
// the views read plain fields: they never touch lastIpcObject or build a dispatch string.
Singleton {
  id: root

  // Workspaces that are always listed, even empty; any other live id is added after them.
  readonly property int persistent: 5

  // Every workspace the bar's pill lists: the persistent ones, then any other live id.
  readonly property var allIds: {
    var seen = {};
    var out = [];
    for (var i = 1; i <= persistent; i++) {
      seen[i] = true;
      out.push(i);
    }
    var all = Hyprland.workspaces.values;
    for (var j = 0; j < all.length; j++) {
      var id = all[j].id;
      if (id > 0 && !seen[id]) {
        seen[id] = true;
        out.push(id);
      }
    }
    out.sort(function (a, b) {
      return a - b;
    });
    return out;
  }

  // How wide that pill is, which the Overview grows out of: its padding, a slot per workspace
  // (the active ones longer) and the gaps between.
  readonly property real pillWidth: {
    var slots = 0;
    for (var i = 0; i < allIds.length; i++) {
      var ws = workspaceFor(allIds[i]);
      slots += ws !== null && ws.active ? Theme.workspaceSlotActiveWidth : Theme.workspaceSlotWidth;
    }
    return Theme.workspacePadding * 2 + slots + Theme.workspaceGap * Math.max(0, allIds.length - 1);
  }

  // Workspace 5 lives on the external output when one is connected and the rest on the
  // laptop panel; this is the same rule home/desktop.nix pins workspaces by.
  function homeOf(id) {
    var internal = "";
    var external = "";
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var name = Quickshell.screens[i].name;
      if (name.indexOf("eDP") === 0)
        internal = name;
      else
        external = name;
    }
    if (internal !== "" && external !== "")
      return id === 5 ? external : internal;
    return "";
  }

  function workspaceFor(id) {
    var all = Hyprland.workspaces.values;
    for (var i = 0; i < all.length; i++) {
      if (all[i].id === id)
        return all[i];
    }
    return null;
  }

  // The workspace ids shown on an output, ascending: the persistent ones whose home it is
  // (or all of them on a lone output) plus any other live workspace sitting on it.
  function idsFor(screenName) {
    var seen = {};
    var out = [];
    for (var i = 1; i <= persistent; i++) {
      var ws = workspaceFor(i);
      var home = ws && ws.monitor ? ws.monitor.name : homeOf(i);
      if (home === "" || home === screenName) {
        seen[i] = true;
        out.push(i);
      }
    }
    var all = Hyprland.workspaces.values;
    for (var j = 0; j < all.length; j++) {
      var id = all[j].id;
      if (id > 0 && !seen[id] && all[j].monitor && all[j].monitor.name === screenName) {
        seen[id] = true;
        out.push(id);
      }
    }
    out.sort(function (a, b) {
      return a - b;
    });
    return out;
  }

  // Every ordinary window, as plain objects: address, title, class, the app's display name,
  // workspace id, output name, and the box in that output's own logical px.
  readonly property var windows: {
    var out = [];
    var all = Hyprland.toplevels.values;
    for (var i = 0; i < all.length; i++) {
      var tl = all[i];
      var ipc = tl.lastIpcObject || {};
      if (!ipc.mapped || !ipc.workspace || ipc.workspace.id <= 0 || !tl.monitor)
        continue;
      var mon = tl.monitor;
      var klass = String(ipc.class || "");
      var entry = klass !== "" ? DesktopEntries.heuristicLookup(klass) : null;
      out.push({
        address: "0x" + tl.address,
        title: String(tl.title || ipc.title || ""),
        appClass: klass,
        appName: entry && entry.name ? String(entry.name) : klass,
        ws: ipc.workspace.id,
        output: mon.name,
        x: (ipc.at ? ipc.at[0] : 0) - mon.x,
        y: (ipc.at ? ipc.at[1] : 0) - mon.y,
        w: ipc.size ? ipc.size[0] : 0,
        h: ipc.size ? ipc.size[1] : 0,
        floating: ipc.floating === true,
        focused: tl.activated,
        toplevel: tl.wayland
      });
    }
    return out;
  }

  // An output's logical size, which is what window boxes are measured against.
  function outputSize(screenName) {
    var all = Hyprland.monitors.values;
    for (var i = 0; i < all.length; i++) {
      var m = all[i];
      if (m.name !== screenName)
        continue;
      var ipc = m.lastIpcObject || {};
      var scale = ipc.scale > 0 ? ipc.scale : 1;
      var rotated = ipc.transform % 2 === 1;
      var w = (rotated ? ipc.height : ipc.width) / scale;
      var h = (rotated ? ipc.width : ipc.height) / scale;
      return {
        width: w > 0 ? w : 1920,
        height: h > 0 ? h : 1080
      };
    }
    return {
      width: 1920,
      height: 1080
    };
  }

  // The lowest workspace id with nothing on it, anywhere: where a window dropped on the
  // "New" strip goes.
  function lowestEmpty() {
    var used = {};
    for (var i = 0; i < windows.length; i++)
      used[windows[i].ws] = true;
    var id = 1;
    while (used[id])
      id++;
    return id;
  }

  // Reads Hyprland again, since a window's box is only re-read on the events that move it.
  function refresh() {
    Hyprland.refreshWorkspaces();
    Hyprland.refreshMonitors();
    Hyprland.refreshToplevels();
  }

  // The Overview asks to be kept current while it is open: a window moved, opened or closed
  // (by it or by anything else) changes the boxes of every window around it, and Hyprland's
  // objects are not re-read for that on their own. Counted, since there is one per output.
  property int watching: 0

  function watch(on) {
    watching = Math.max(0, watching + (on ? 1 : -1));
  }

  Timer {
    id: settle

    interval: 80
    onTriggered: root.refresh()
  }

  Connections {
    target: Hyprland
    enabled: root.watching > 0

    // Bursts (a close re-tiles a whole workspace) are read once, after they settle.
    function onRawEvent(event) {
      switch (event.name) {
      case "openwindow":
      case "closewindow":
      case "movewindowv2":
      case "fullscreen":
      case "changefloatingmode":
      case "workspacev2":
      case "createworkspacev2":
      case "destroyworkspacev2":
        settle.restart();
      }
    }
  }

  function focusWindow(address) {
    Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })");
  }

  function moveWindow(address, ws) {
    Hyprland.dispatch("hl.dsp.window.move({ workspace = " + ws + ", window = \"address:" + address + "\" })");
  }

  function closeWindow(address) {
    Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + address + "\" })");
  }

  function goTo(ws) {
    Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws + " })");
  }
}
