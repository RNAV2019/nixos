pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services

// The shell's interface sounds: quiet, short, and off with one switch (Control centre > Audio >
// Interface sounds). This is the only place that knows which event makes which sound; the
// services and views just announce what happened and Sounds listens, so there is one table to read
// and one to change (`catalog`, `momentSounds`, and the connections below).
//
// The sounds are synthesised at build time (pkgs/quickshell-sounds) and linked into
// ~/.local/share/quickshell/sounds by home/desktop.nix. This Qt has no QtMultimedia, so each
// is played by a short-lived `pw-play`; it starts in a few tens of milliseconds and a handful may
// overlap.
//
// What is let through:
//   - nothing, while `enabled` is off (saved under Paths.stateDir, on by default);
//   - nothing in the first `startupQuiet` ms, so starting or reloading the shell is silent;
//   - only `urgent` sounds while Peace is on (Services/NotificationStore.qml);
//   - not the same sound again within its `gap`, so a held volume key ticks rather than rattles.
Singleton {
  id: root

  property bool enabled: true

  // The sounds. `gap`: the least time between two plays of it, in ms. `urgent`: still sounds
  // under Peace. `file` is the name under the sounds directory when it differs from the key.
  readonly property var catalog: ({
      "tick": {
        "gap": 90
      },
      "shutter": {
        "gap": 300
      },
      "plugged": {
        "gap": 800
      },
      "timer": {
        "gap": 1500,
        "urgent": true
      },
      "chime": {
        "gap": 400
      },
      "chime-urgent": {
        "gap": 400,
        "urgent": true
      },
      "attention": {
        "gap": 700
      },
      "success": {
        "gap": 500
      },
      "failure": {
        "gap": 500
      },
      "received": {
        "gap": 500
      },
      "lock": {
        "gap": 1000
      },
      "unlock": {
        "gap": 1000
      }
    })

  // A moment's kind (Services/Activities.qml) and the sound it raises. A kind not listed is
  // silent, which is what the test and demo moments want.
  readonly property var momentSounds: ({
      "timer-done": "timer",
      "pomodoro-phase": "timer",
      "plugged-in": "plugged",
      "usb-inserted": "plugged",
      "event-reminder": "attention",
      "wifi-signin": "attention",
      "claude-permission": "attention",
      "claude-question": "attention",
      "claude-finished": "chime",
      "rebuild-finished": "success",
      "usb-safe": "success",
      "rebuild-failed": "failure",
      "usb-error": "failure"
    })

  // How long after the shell starts nothing sounds, and how long the alarm waits between
  // repeats, and how many times it repeats, until it is answered.
  readonly property int startupQuiet: 4000
  readonly property int alarmInterval: 6000
  readonly property int alarmRepeats: 4
  readonly property int maxLive: 4

  // QS_SOUNDS_DIR and QS_SOUNDS_PLAYER exist for the tests: a directory of stand-ins, and a
  // player that logs instead of playing.
  readonly property string directory: Quickshell.env("QS_SOUNDS_DIR") || (Quickshell.env("XDG_DATA_HOME") || Paths.home + "/.local/share") + "/quickshell/sounds"
  readonly property string player: Quickshell.env("QS_SOUNDS_PLAYER") || "pw-play"

  property bool _quiet: true
  property var _last: ({})
  property int _live: 0
  property bool _warned: false
  property int _alarmRuns: 0

  // Starts the shell's listening: a singleton does nothing until something uses it.
  function start() {
    quietTimer.restart();
  }

  // Plays `name` if the gates let it through. Returns whether it played.
  function play(name) {
    var sound = root.catalog[name];
    if (!sound || root._quiet || !root.enabled)
      return false;
    if (NotificationStore.peace && !sound.urgent)
      return false;
    var now = Date.now();
    if (now - (root._last[name] || 0) < sound.gap)
      return false;
    if (root._live >= root.maxLive)
      return false;
    root._last[name] = now;
    root._live++;
    var run = runner.createObject(root, {
      "command": [root.player, root.directory + "/" + name + ".wav"],
      "sound": name
    });
    run.running = true;
    return true;
  }

  function status() {
    return (root.enabled ? "on" : "off") + (NotificationStore.peace ? " peace" : "") + (root._quiet ? " starting" : "");
  }

  Timer {
    id: quietTimer

    interval: root.startupQuiet
    running: true
    onTriggered: root._quiet = false
  }

  Component {
    id: runner

    Process {
      property string sound: ""

      onExited: function (code) {
        root._live--;
        if (code !== 0 && !root._warned) {
          root._warned = true;
          console.warn("sounds: " + root.player + " failed for " + sound + " (" + code + ")");
        }
        destroy();
      }
    }
  }

  // ---- the switch, saved ----

  property bool _touched: false

  onEnabledChanged: {
    root._touched = true;
    saved.setText(root.enabled ? "1" : "0");
    if (!root.enabled)
      alarm.stop();
  }

  FileView {
    id: saved

    path: Paths.stateDir + "/sounds"
    printErrors: false

    onLoaded: {
      if (root._touched)
        return;
      if (saved.text().trim() === "0")
        root.enabled = false;
    }
  }

  // ---- events ----

  Connections {
    target: Activities

    function onMomentRaised(kind) {
      root.play(root.momentSounds[kind]);
      if (kind === "timer-done") {
        root._alarmRuns = 0;
        alarm.restart();
      }
    }

    function onMomentDismissed(kind) {
      if (kind === "timer-done" && !Activities.moments.some(m => m.kind === "timer-done"))
        alarm.stop();
    }
  }

  // A timer's alarm rings again until it is answered, a few times, in case nobody is there.
  Timer {
    id: alarm

    interval: root.alarmInterval
    repeat: true
    onTriggered: {
      if (!Activities.moments.some(m => m.kind === "timer-done") || ++root._alarmRuns > root.alarmRepeats)
        stop();
      else
        root.play("timer");
    }
  }

  Connections {
    target: NotificationStore

    function onNotified(urgent) {
      root.play(urgent ? "chime-urgent" : "chime");
    }
  }

  Connections {
    target: Volume

    function onAdjusted() {
      root.play("tick");
    }
  }

  Connections {
    target: Captures

    function onAdded(kind) {
      if (kind === "screenshot")
        root.play("shutter");
    }

    function onFailed() {
      root.play("failure");
    }
  }

  // The lock fires its sound as the shell begins to lock and as it begins to reveal, from the
  // flag the lock already raises; the boot lock falls inside the quiet start.
  Connections {
    target: Bus

    function onLockingChanged() {
      root.play(Bus.locking ? "lock" : "unlock");
    }
  }

  // A transfer finishing: an arrival sounds as received, a send as a success. The daemon
  // repeats its whole list on every event and replays it after a reconnect, so what has
  // finished is remembered, and whatever arrives in the first moments of a connection only
  // fills that memory.
  property var _finished: ({})
  property bool _seeded: false

  Timer {
    id: seedTimer

    interval: 1500
    running: true
    onTriggered: root._seeded = true
  }

  Connections {
    target: Nearby

    function onTransfersChanged() {
      var heard = "";
      for (var i = 0; i < Nearby.transfers.length; i++) {
        var t = Nearby.transfers[i];
        if (t.state !== "finished" || root._finished[t.id])
          continue;
        root._finished[t.id] = true;
        if (t.direction === "in")
          heard = "received";
        else if (heard === "")
          heard = "success";
      }
      if (root._seeded && heard !== "")
        root.play(heard);
    }

    function onConnectedChanged() {
      root._seeded = false;
      if (Nearby.connected)
        seedTimer.restart();
    }
  }
}
