pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The screen recorder. Boards 08 and 09.
//
// Recording is one long-lived process, wl-screenrec, which writes until it is
// asked to stop. Everything here is about the three moments around it: working
// out what to point it at, knowing while it runs, and saying where the file
// went once it has.
//
// wl-screenrec rather than wf-recorder because the toggles on board 08 have to
// be real. wf-recorder always burns the cursor in and offers no way to say
// otherwise; wl-screenrec has --no-cursor, takes slurp's own geometry format,
// and records audio from a named device. A toggle the recorder cannot honour
// would be worse than no toggle at all.
//
// Stopping is SIGINT, never SIGKILL: the muxer has to write its trailer or the
// file is unplayable. That is also why `saving` exists as a state of its own -
// there is a moment after the user has asked to stop where the recording is
// still being finished, and claiming it was saved before then would be a lie.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string directory: home + "/Videos/recordings"

  // "idle" -> "picking" -> "recording" -> "saving" -> "idle".
  //
  // `picking` covers the slurp call for a window or a region, which is a
  // separate process the user is interacting with, and during which the shell
  // must not claim to be recording.
  property string state: "idle"

  readonly property bool recording: state === "recording"
  readonly property bool busy: state !== "idle"

  // What the picker was left on. These outlive a recording, so the next one
  // opens on the same answers rather than back at the defaults.
  property string target: "screen"
  property bool cursor: true
  property bool desktopAudio: true
  property bool microphone: false

  property string file: ""
  property int elapsed: 0

  readonly property string elapsedLabel: {
    var m = Math.floor(root.elapsed / 60);
    var s = root.elapsed % 60;
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
  }

  readonly property string targetLabel: target === "screen" ? "Screen" : target === "window" ? "Window" : "Region"

  // What the control centre tile says under its name.
  readonly property string status: {
    if (root.state === "recording")
      return root.targetLabel + " · " + root.elapsedLabel + "  ·  tap to stop";
    if (root.state === "saving")
      return "Saving…";
    if (root.state === "picking")
      return "Choose an area…";
    return "Off";
  }

  signal saved(string path)
  signal failed(string reason)

  function toggle() {
    if (root.busy)
      root.stop();
    else
      Bus.recorderRequested();
  }

  // Called by the picker once the user has chosen. A window or a region needs
  // slurp first, and slurp cannot run while the picker surface is holding the
  // keyboard - the picker closes itself before this is reached.
  function start() {
    if (root.busy)
      return;

    if (root.target === "screen") {
      root.begin("");
      return;
    }

    root.state = "picking";
    // For a window the candidate rectangles are the clients on the active
    // workspace, which slurp draws as snap targets; for a region it is a free
    // drag. Either way slurp prints one "x,y WxH" that wl-screenrec takes
    // verbatim.
    pick.command = root.target === "window" ? ["sh", "-c", 'ws=$(hyprctl -j activeworkspace | jq -r .id); hyprctl -j clients | jq -r --argjson ws "$ws" \'.[] | select(.workspace.id == $ws and .hidden == false) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"\' | slurp -r'] : ["slurp"];
    pick.running = true;
  }

  function begin(geometry) {
    var stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss");
    root.file = root.directory + "/" + stamp + ".mp4";

    var args = ["wl-screenrec", "-f", root.file];
    if (geometry !== "")
      args.push("-g", geometry);
    if (!root.cursor)
      args.push("--no-cursor");

    // One device, because wl-screenrec mixes nothing: it takes a single
    // --audio-device. Desktop audio is the default sink's monitor, the
    // microphone is the default source, and with both asked for the desktop
    // wins. The name is resolved in the shell below rather than here, because
    // it is whatever wireplumber currently calls the default - a bluetooth
    // headset that connects between two recordings changes it.
    var device = "";
    if (root.desktopAudio)
      device = 'sink';
    else if (root.microphone)
      device = 'source';

    root.elapsed = 0;
    // The directory is made here rather than at start-up, so a recorder that is
    // never used never creates anything. The whole thing is one shell so the
    // device lookup happens at the moment of recording.
    var script = 'mkdir -p "$(dirname "$1")" || exit 1; kind=$2; shift 2; ' + 'if [ -n "$kind" ]; then ' + 'alias=@DEFAULT_AUDIO_SINK@; [ "$kind" = source ] && alias=@DEFAULT_AUDIO_SOURCE@; ' + 'name=$(wpctl inspect "$alias" | sed -n \'s/.*node\\.name = "\\(.*\\)"/\\1/p\' | head -1); ' + '[ "$kind" = sink ] && name="$name.monitor"; ' + 'if [ -n "$name" ]; then set -- "$@" --audio --audio-device "$name"; fi; fi; ' + 'exec "$@"';
    capture.command = ["sh", "-c", script, "sh", root.file, device].concat(args);
    capture.running = true;
    root.state = "recording";
    tick.restart();
  }

  // SIGINT, so the muxer closes the file properly. See the note at the top.
  function stop() {
    if (root.state === "picking") {
      pick.running = false;
      root.state = "idle";
      return;
    }
    if (root.state !== "recording")
      return;
    root.state = "saving";
    tick.stop();
    // SIGINT by hand, because Quickshell's Process has no signal method of its
    // own and setting running to false would terminate rather than interrupt.
    // The muxer has to write its trailer or the file will not play. The signal
    // goes to the process group, since the recorder is started under a shell
    // and it is the shell's child that has to receive it.
    interrupt.command = ["sh", "-c", 'kill -INT -"$1" 2>/dev/null || kill -INT "$1"', "sh", String(capture.processId)];
    interrupt.running = true;
  }

  Process {
    id: interrupt
  }

  Timer {
    id: tick

    interval: 1000
    repeat: true
    onTriggered: root.elapsed = root.elapsed + 1
  }

  Process {
    id: pick

    stdout: StdioCollector {
      onStreamFinished: {
        var g = text.trim();
        // An empty answer is the user pressing Escape in slurp, which is a
        // cancel and not a failure.
        if (g === "")
          root.state = "idle";
        else
          root.begin(g);
      }
    }

    onExited: function (code) {
      if (code !== 0 && root.state === "picking")
        root.state = "idle";
    }
  }

  Process {
    id: capture

    stderr: StdioCollector {}

    // Code 0 is a clean stop. Anything else on the way out of `saving` still
    // produced a file often enough to be worth checking for, but a failure
    // before the first frame leaves nothing, so the file is stat'ed rather
    // than assumed.
    onExited: function (code) {
      tick.stop();
      var wanted = root.file;
      root.state = "idle";
      if (wanted === "")
        return;
      confirm.command = ["sh", "-c", '[ -s "$1" ] && stat -c %s "$1" || true', "sh", wanted];
      confirm.target = wanted;
      confirm.running = true;
    }
  }

  // Nothing is announced until the file is on disk with something in it.
  Process {
    id: confirm

    property string target: ""

    stdout: StdioCollector {
      onStreamFinished: {
        var size = text.trim();
        if (size === "") {
          root.failed("Nothing was recorded");
          return;
        }
        root.saved(confirm.target);
        announce.command = ["sh", "-c", 'notify-send -a "Screen Recorder" -A "open=Open" -A "folder=Show in folder" "Recording saved" "$1"', "sh", confirm.target.substring(confirm.target.lastIndexOf("/") + 1)];
        announce.target = confirm.target;
        announce.running = true;
      }
    }
  }

  // The shell is the notification server, so its own notification goes out the
  // same door as everyone else's and comes back in as a toast with real
  // actions. notify-send holds until one is chosen and prints its name.
  Process {
    id: announce

    property string target: ""

    stdout: StdioCollector {
      onStreamFinished: {
        var choice = text.trim();
        if (choice === "open")
          open.command = ["xdg-open", announce.target];
        else if (choice === "folder")
          open.command = ["xdg-open", announce.target.substring(0, announce.target.lastIndexOf("/"))];
        else
          return;
        open.running = true;
      }
    }
  }

  Process {
    id: open
  }
}
