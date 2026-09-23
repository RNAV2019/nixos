pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The screen recorder: one long-lived wl-screenrec process, chosen over wf-recorder so
// the toggles are real. Stop is SIGINT, never SIGKILL, so the muxer writes its trailer.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string directory: home + "/Videos/recordings"

  // "idle" -> "picking" -> "recording" -> "saving" -> "idle".
  property string state: "idle"

  readonly property bool recording: state === "recording"
  readonly property bool busy: state !== "idle"

  // What the picker was left on; these outlive a recording, so the next opens on them.
  property string target: "screen"
  property bool cursor: true
  property bool desktopAudio: true
  property bool microphone: false

  property string file: ""
  property int elapsed: 0
  property bool pendingStop: false

  readonly property string elapsedLabel: {
    var m = Math.floor(root.elapsed / 60);
    var s = root.elapsed % 60;
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
  }

  readonly property string targetLabel: target === "screen" ? "Screen" : target === "window" ? "Window" : "Region"

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

  // Called by the picker once chosen; it closes itself first, since slurp cannot run
  // while that surface holds the keyboard.
  function start() {
    if (root.busy)
      return;

    if (root.target === "screen") {
      root.begin("");
      return;
    }

    root.state = "picking";
    // slurp prints one "x,y WxH" that wl-screenrec takes verbatim.
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

    // wl-screenrec takes a single --audio-device and mixes nothing, so one device only;
    // with both asked for the desktop wins. The name is resolved in the shell below.
    var device = "";
    if (root.desktopAudio)
      device = 'sink';
    else if (root.microphone)
      device = 'source';

    root.elapsed = 0;
    root.pendingStop = false;
    // One shell, so the device lookup happens at record time. The directory is made here,
    // so a recorder that is never used creates nothing.
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
    requestInterrupt();
  }

  function requestInterrupt() {
    if (!capture.running)
      return;
    if (capture.processId <= 0) {
      pendingStop = true;
      stopWait.restart();
      return;
    }
    pendingStop = false;
    // SIGINT by hand: terminating would skip the muxer's trailer. It goes to the process
    // group because the capture command is wrapped in a shell.
    interrupt.command = ["sh", "-c", 'kill -INT -"$1" 2>/dev/null || kill -INT "$1"', "sh", String(capture.processId)];
    interrupt.running = true;
  }

  Process {
    id: interrupt
  }

  Timer {
    id: stopWait

    interval: 16
    repeat: true
    onTriggered: {
      if (!root.pendingStop || !capture.running) {
        stopWait.stop();
        return;
      }
      if (capture.processId > 0) {
        stopWait.stop();
        root.requestInterrupt();
      }
    }
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
        // An empty answer is Escape in slurp, which is a cancel and not a failure.
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

    // A failure before the first frame leaves nothing, so the file is stat'ed, not assumed.
    onExited: function (code) {
      tick.stop();
      pendingStop = false;
      stopWait.stop();
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

  // The shell is the notification server, so this comes back as a toast with real actions.
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
