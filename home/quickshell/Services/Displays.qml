pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland's monitor state, read from `hyprctl -j monitors all` and written
// back through the Lua config API.
//
// `hyprctl keyword` is not available under configType = "lua"; it answers
// "unknown request". `hyprctl eval` runs a Lua string against the live config
// instead, and several hl.monitor calls in one string land as a single change
// rather than a flicker of intermediate layouts.
Singleton {
  id: root

  readonly property int fastInterval: 2000
  readonly property int idleInterval: 30000

  property int subscribers: 0

  function subscribe() {
    subscribers++;
    refresh();
  }
  function unsubscribe() {
    subscribers = Math.max(0, subscribers - 1);
  }

  // One entry per output, enabled or not. See _parse for the shape.
  property var monitors: []
  property bool ready: false

  readonly property var activeMonitors: {
    var out = [];
    for (var i = 0; i < monitors.length; i++) {
      if (!monitors[i].disabled)
        out.push(monitors[i]);
    }
    return out;
  }

  // Identifies a set of connected outputs so a layout can be recalled for it.
  // The connector name alone is not enough, because the same dock port can
  // hand out a different name; the description alone is not enough either,
  // because headless outputs have none.
  readonly property string fingerprint: {
    var ids = [];
    for (var i = 0; i < monitors.length; i++)
      ids.push(monitors[i].name + "|" + monitors[i].description);
    ids.sort();
    return ids.join(" + ");
  }

  readonly property string label: {
    var names = [];
    for (var i = 0; i < monitors.length; i++)
      names.push(monitors[i].name);
    names.sort();
    return names.join(" + ");
  }

  signal applied

  // Raised between an apply and the reread that confirms it, so anything
  // persisting the result works from the new state rather than the old.
  property bool _awaitingApply: false

  function find(name) {
    for (var i = 0; i < monitors.length; i++) {
      if (monitors[i].name === name)
        return monitors[i];
    }
    return null;
  }

  function refresh() {
    if (!query.running)
      query.running = true;
  }

  // Hyprland reports mode resolution, but positions the output by its logical
  // size. Everything laid out on the map has to agree with the compositor, so
  // divide through by the scale.
  function logicalWidth(m) {
    return m.scale > 0 ? Math.round(m.width / m.scale) : m.width;
  }
  function logicalHeight(m) {
    return m.scale > 0 ? Math.round(m.height / m.scale) : m.height;
  }

  function formatMode(m) {
    return m.width + "x" + m.height + "@" + Math.round(m.refreshRate);
  }

  // Output names come from the compositor, but a quoted string is being built
  // by hand here, so drop anything that could close it early.
  function _lua(s) {
    return String(s).replace(/[^A-Za-z0-9_.:@ -]/g, "");
  }

  // Each entry: { output, mode, position, scale, disabled, mirror }. Omitted
  // fields fall back to the monitor's current state, and `disabled` is always
  // written because Hyprland keeps an output off until told otherwise.
  function apply(rules) {
    if (!rules || rules.length === 0)
      return;

    var calls = [];
    for (var i = 0; i < rules.length; i++) {
      var r = rules[i];
      var parts = ['output = "' + _lua(r.output) + '"'];

      if (r.disabled) {
        parts.push("disabled = true");
      } else {
        parts.push("disabled = false");
        parts.push('mode = "' + _lua(r.mode || "preferred") + '"');
        parts.push('position = "' + _lua(r.position || "auto") + '"');
        parts.push("scale = " + (r.scale > 0 ? r.scale : 1));
        parts.push('mirror = "' + _lua(r.mirror || "") + '"');
      }

      calls.push("hl.monitor({ " + parts.join(", ") + " })");
    }

    _awaitingApply = true;
    setter.command = ["hyprctl", "eval", calls.join("; ")];
    setter.running = true;
  }

  Process {
    id: setter
    onExited: {
      // The compositor needs a moment to settle before it reports the result.
      settle.restart();
    }
  }

  Timer {
    id: settle
    interval: 250
    onTriggered: root.refresh()
  }

  Process {
    id: query
    command: ["hyprctl", "-j", "monitors", "all"]
    stdout: StdioCollector {
      onStreamFinished: root._parse(text)
    }
  }

  Timer {
    running: true
    repeat: true
    triggeredOnStart: true
    interval: root.subscribers > 0 ? root.fastInterval : root.idleInterval
    onTriggered: root.refresh()
  }

  // Hotplug and config reloads both change the layout underneath us.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "monitoradded" || event.name === "monitorremoved" || event.name === "monitorremovedv2" || event.name === "configreloaded")
        settle.restart();
    }
  }

  // "1920x1200@60.00Hz" as reported in availableModes.
  function _parseMode(s) {
    var m = String(s).match(/^(\d+)x(\d+)@([\d.]+)/);
    if (!m)
      return null;
    return {
      width: parseInt(m[1]),
      height: parseInt(m[2]),
      refreshRate: parseFloat(m[3]),
      text: m[1] + "x" + m[2] + "@" + Math.round(parseFloat(m[3]))
    };
  }

  function _parse(text) {
    var raw;
    try {
      raw = JSON.parse(text);
    } catch (e) {
      return;
    }
    if (!Array.isArray(raw))
      return;

    var out = [];
    for (var i = 0; i < raw.length; i++) {
      var m = raw[i];

      var modes = [];
      var available = m.availableModes || [];
      for (var j = 0; j < available.length; j++) {
        var parsed = _parseMode(available[j]);
        if (parsed)
          modes.push(parsed);
      }

      // A disabled output reports no geometry, so fall back to its first mode
      // to give the map something to draw.
      var width = m.width || (modes.length > 0 ? modes[0].width : 0);
      var height = m.height || (modes.length > 0 ? modes[0].height : 0);

      out.push({
        id: m.id,
        name: m.name,
        description: m.description || "",
        make: m.make || "",
        model: m.model || "",
        x: m.x || 0,
        y: m.y || 0,
        width: width,
        height: height,
        refreshRate: m.refreshRate || (modes.length > 0 ? modes[0].refreshRate : 0),
        scale: m.scale || 1,
        disabled: m.disabled === true,
        focused: m.focused === true,
        // Reported as the mirrored monitor's id; resolved to its name below.
        mirrorOf: m.mirrorOf && m.mirrorOf !== "none" ? String(m.mirrorOf) : "",
        modes: modes
      });
    }

    for (var k = 0; k < out.length; k++) {
      if (out[k].mirrorOf === "")
        continue;
      for (var n = 0; n < out.length; n++) {
        if (String(out[n].id) === out[k].mirrorOf) {
          out[k].mirrorOf = out[n].name;
          break;
        }
      }
    }

    out.sort(function (a, b) {
      return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
    });

    root.monitors = out;
    root.ready = true;

    if (root._awaitingApply) {
      root._awaitingApply = false;
      root.applied();
    }
  }
}
