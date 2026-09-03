pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services

// Remembers a monitor layout per set of connected outputs and reapplies it on
// hotplug, so docking and undocking needs no interaction.
//
// The store lives in the nixos repo rather than under ~/.local/state because
// home/desktop.nix reads the same file to seed Hyprland's monitor rules. That
// keeps one source of truth for the live session and the next rebuild, at the
// cost of needing the file staged in git before a flake evaluation sees it.
Singleton {
  id: root

  readonly property string storePath: Quickshell.env("HOME") + "/nixos/home/monitors.json"

  property var store: ({
      active: "",
      profiles: {}
    })
  property bool loaded: false

  readonly property string fingerprint: Displays.fingerprint
  readonly property var current: loaded && store.profiles ? (store.profiles[fingerprint] || null) : null
  readonly property string label: current && current.label ? current.label : Displays.label

  // Snapshot the live layout into the profile for the current set of outputs.
  function save() {
    if (!loaded || !Displays.ready || Displays.monitors.length === 0)
      return;

    var monitors = [];
    for (var i = 0; i < Displays.monitors.length; i++) {
      var m = Displays.monitors[i];
      monitors.push({
        output: m.name,
        mode: Displays.formatMode(m),
        position: m.x + "x" + m.y,
        scale: m.scale,
        disabled: m.disabled,
        mirrorOf: m.mirrorOf
      });
    }

    var profiles = {};
    for (var key in store.profiles)
      profiles[key] = store.profiles[key];

    profiles[fingerprint] = {
      label: Displays.label,
      monitors: monitors
    };

    store = {
      active: fingerprint,
      profiles: profiles
    };
    _write();
  }

  function applyCurrent() {
    if (!current || !current.monitors)
      return;

    var rules = [];
    for (var i = 0; i < current.monitors.length; i++) {
      var m = current.monitors[i];
      rules.push({
        output: m.output,
        mode: m.mode,
        position: m.position,
        scale: m.scale,
        disabled: m.disabled === true,
        mirror: m.mirrorOf || ""
      });
    }
    Displays.apply(rules);
  }

  function _write() {
    storeFile.setText(JSON.stringify(store, null, 2) + "\n");
  }

  // A new set of outputs either has a remembered layout to restore or becomes
  // one. Applying does not change which outputs are present, so this cannot
  // feed back into itself.
  onFingerprintChanged: reconcile.restart()
  onLoadedChanged: reconcile.restart()

  Timer {
    id: reconcile
    interval: 400
    onTriggered: {
      if (!root.loaded || !Displays.ready || root.fingerprint === "")
        return;
      if (root.current)
        root.applyCurrent();
      else
        root.save();
    }
  }

  // Auto-save: every applied layout becomes the profile for the outputs it
  // was applied to, whether it came from the panel, a hotplug or a hotkey.
  Connections {
    target: Displays

    function onApplied() {
      root.save();
    }
  }

  // Hyprland re-executes hyprland.lua on every reload, which reasserts the
  // monitor rules nix baked in. Reapply on top so a live layout is not lost.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded")
        reassert.restart();
    }
  }

  Timer {
    id: reassert
    interval: 600
    onTriggered: root.applyCurrent()
  }

  FileView {
    id: storeFile

    path: root.storePath
    watchChanges: true
    // The file may not exist yet on a fresh checkout.
    printErrors: false

    onFileChanged: storeFile.reload()

    onLoaded: {
      var parsed;
      try {
        parsed = JSON.parse(storeFile.text());
      } catch (e) {
        parsed = null;
      }
      if (parsed && typeof parsed === "object")
        root.store = {
          active: parsed.active || "",
          profiles: parsed.profiles || {}
        };
      root.loaded = true;
    }

    onLoadFailed: root.loaded = true
  }
}
