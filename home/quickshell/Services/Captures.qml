pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services

// Screenshots and recordings, and the tray that announces them (Capture/CaptureTray.qml). A
// screenshot is taken here: pick (slurp, for a region or a window), wait for the tray to be
// off the screen, grim into the screenshots folder and the clipboard. A finished recording
// arrives from Recorder. Either way it is pushed onto the stack the tray draws, newest first.
Singleton {
  id: root

  readonly property string directory: {
    var dir = Quickshell.env("XDG_SCREENSHOTS_DIR");
    return dir ? dir : Paths.home + "/Pictures/screenshots";
  }

  // Thumbnails of recordings, so the tray never decodes a video itself.
  readonly property string thumbDirectory: {
    var cache = Quickshell.env("XDG_CACHE_HOME");
    return (cache ? cache : Paths.home + "/.cache") + "/quickshell/captures";
  }

  // Captures in the tray, newest first: { path, name, kind, width, height, bytes, seconds,
  // thumb, note }. Kept after the tray goes, so its contents do not blank mid-retreat; a
  // capture arriving once the tray is gone starts a fresh stack.
  property var items: []
  readonly property int count: items.length
  // Which of them the card shows; the badge steps it through the stack.
  property int viewIndex: 0
  readonly property var current: items.length > 0 ? items[Math.min(viewIndex, items.length - 1)] : null

  // Whether the tray wants the island, and a counter that restarts its dwell.
  property bool trayWanted: false
  property int revision: 0

  // A capture in progress: picking, or waiting for the tray to clear the screen.
  property string state: "idle"
  readonly property bool busy: state !== "idle"

  // The tray's own window being up, written by it, so a capture waits for the tray to leave.
  readonly property bool trayShowing: Bus.transientScreen("captures") !== ""

  property string pendingMode: ""
  property string pendingGeometry: ""
  property string pendingOutput: ""

  // Raised when something needs saying that is not a capture: a failed grim, say.
  signal failed(string reason)

  readonly property var screenshots: items.filter(function (i) {
    return i.kind === "screenshot";
  })

  // ---- taking a screenshot ----

  // "region" and "window" ask first; "output" is the focused output, "screen" every output.
  function begin(mode) {
    if (root.busy)
      return;
    Bus.closeSurface("screentools");
    root.pendingMode = mode;
    root.pendingGeometry = "";
    root.pendingOutput = mode === "output" ? Monitors.focusedName : "";
    root.retreat();
    if (mode === "region") {
      root.state = "picking";
      pick.exec(["slurp"]);
    } else if (mode === "window") {
      root.state = "picking";
      // Windows on every visible workspace, drawn as boxes slurp can snap to.
      pick.exec(["sh", "-c", 'ws=$(hyprctl -j monitors | jq -r "[.[].activeWorkspace.id] | @json"); ' + 'hyprctl -j clients | jq -r --argjson ws "$ws" \'.[] | select(.mapped and (.hidden | not) and (.workspace.id as $i | $ws | index($i) != null)) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"\' | slurp -r']);
    } else {
      root.settle();
    }
  }

  function picked(geometry) {
    root.pendingGeometry = geometry;
    root.settle();
  }

  // The tray (and anything else on the island) has to be off the screen before grim looks.
  function settle() {
    root.state = "waiting";
    settleWait.interval = root.trayShowing ? Theme.actionSettleDelay : 40;
    settleWait.restart();
  }

  function shoot() {
    var stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss");
    var file = root.directory + "/Screenshot " + stamp + ".png";
    root.state = "saving";
    var script = 'mkdir -p "$(dirname "$1")" || exit 1; out=$1; geo=$2; output=$3; ' + 'if [ -n "$geo" ]; then grim -l 3 -g "$geo" "$out"; elif [ -n "$output" ]; then grim -l 3 -o "$output" "$out"; else grim -l 3 "$out"; fi || exit 1; ' + 'wl-copy --type image/png < "$out" > /dev/null 2>&1; ' + 'stat -c %s "$out"; file -bL "$out"';
    shot.target = file;
    shot.exec(["sh", "-c", script, "sh", file, root.pendingGeometry, root.pendingOutput]);
  }

  Timer {
    id: settleWait

    onTriggered: root.shoot()
  }

  Command {
    id: pick

    label: "capture region"
    logFailures: false

    stdout: StdioCollector {
      onStreamFinished: {
        var g = text.trim();
        // An empty answer is Escape in slurp: a cancel, not a failure.
        if (g === "")
          root.state = "idle";
        else
          root.picked(g);
      }
    }

    onFailed: root.state = "idle"
  }

  Command {
    id: shot

    property string target: ""

    label: "screenshot"

    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n");
        if (lines.length < 2) {
          root.state = "idle";
          return;
        }
        var dims = lines[1].match(/(\d+)\s*x\s*(\d+)/);
        root.state = "idle";
        root.add({
          path: shot.target,
          kind: "screenshot",
          bytes: parseInt(lines[0], 10),
          width: dims ? parseInt(dims[1], 10) : 0,
          height: dims ? parseInt(dims[2], 10) : 0,
          seconds: 0,
          thumb: "",
          note: "Copied"
        });
      }
    }

    onFailed: function (code, message) {
      root.state = "idle";
      root.failed(message !== "" ? message : "Screenshot failed");
    }
  }

  // ---- the stack ----

  function nameOf(path) {
    return path.substring(path.lastIndexOf("/") + 1);
  }

  // The tray steps aside for a capture, but the stack is still the stack: what the capture
  // brings goes onto it. It lapses a few seconds after nothing is being captured.
  property bool keepStack: false

  function retreat() {
    root.keepStack = root.keepStack || root.trayWanted;
    root.dismiss();
  }

  Timer {
    running: root.keepStack && !root.busy && !Recorder.busy
    interval: 10000
    onTriggered: root.keepStack = false
  }

  Connections {
    target: Recorder

    function onStateChanged() {
      if (Recorder.state === "picking" || Recorder.state === "recording")
        root.retreat();
    }
  }

  function add(item) {
    item.name = root.nameOf(item.path);
    // The drag's text/uri-list entry; a path is not a URL until its odd characters are escaped.
    item.uri = "file://" + item.path.split("/").map(encodeURIComponent).join("/");
    // Past its dwell the tray is gone, and this starts a new stack.
    var push = root.trayWanted || root.keepStack;
    root.keepStack = false;
    root.items = (push ? [item].concat(root.items) : [item]).slice(0, 12);
    root.viewIndex = 0;
    root.trayWanted = true;
    root.revision++;
  }

  function dismiss() {
    root.trayWanted = false;
  }

  // Clear: the stack goes, the files stay.
  function clear() {
    root.keepStack = false;
    root.trayWanted = false;
  }

  // The badge steps through the stack, newest first, and wraps.
  function step() {
    if (root.count > 1)
      root.viewIndex = (root.viewIndex + 1) % root.count;
    root.revision++;
  }

  function summary() {
    var shots = root.screenshots.length;
    var recs = root.count - shots;
    var parts = [];
    if (shots > 0)
      parts.push(shots + (shots === 1 ? " screenshot" : " screenshots"));
    if (recs > 0)
      parts.push(recs + (recs === 1 ? " recording" : " recordings"));
    return parts.join(" · ");
  }

  // ---- what the tray's buttons do ----

  function open() {
    if (root.current)
      launch.exec(["xdg-open", root.current.path]);
  }

  // Satty edits the file and saves beside it, so the capture itself is never overwritten.
  function annotate() {
    var item = root.current;
    if (!item || item.kind !== "screenshot")
      return;
    var out = item.path.replace(/\.png$/, "") + " (annotated).png";
    root.dismiss();
    editor.exec(["satty", "--filename", item.path, "--output-filename", out, "--copy-command", "wl-copy", "--early-exit"]);
  }

  // The image itself for a screenshot; a recording is a file, so it goes as a file reference.
  function copy() {
    var item = root.current;
    if (!item)
      return;
    if (item.kind === "screenshot")
      clip.exec(["sh", "-c", 'wl-copy --type image/png < "$1" > /dev/null 2>&1', "sh", item.path]);
    else
      clip.exec(["sh", "-c", 'printf "%s\\r\\n" "$1" | wl-copy --type text/uri-list > /dev/null 2>&1', "sh", item.uri]);
  }

  function send() {
    var item = root.current;
    if (!item)
      return;
    root.dismiss();
    Nearby.requestSend([item.path]);
  }

  // To the trash, so it can come back; the card leaves the stack with it.
  function remove() {
    var item = root.current;
    if (!item)
      return;
    trash.exec(["gio", "trash", item.path]);
    var next = root.items.filter(function (i) {
      return i.path !== item.path;
    });
    root.items = next;
    root.viewIndex = 0;
    if (next.length === 0)
      root.dismiss();
    else
      root.revision++;
  }

  Command {
    id: launch

    label: "open capture"
  }

  Command {
    id: editor

    label: "satty"
  }

  Command {
    id: clip

    label: "copy capture"
  }

  Command {
    id: trash

    label: "trash capture"
  }

  // ---- recordings ----

  Connections {
    target: Recorder

    function onSaved(path) {
      root.describeRecording(path, Recorder.elapsed);
    }
  }

  // The first frame for the card, and the size; both done before the card is drawn.
  function describeRecording(path, seconds) {
    var thumb = root.thumbDirectory + "/" + root.nameOf(path).replace(/\.[^.]*$/, "") + ".jpg";
    probe.target = path;
    probe.thumb = thumb;
    probe.seconds = seconds;
    probe.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")"; stat -c %s "$1"; ffmpeg -v error -y -i "$1" -frames:v 1 -vf scale=568:-2 -q:v 3 "$2" < /dev/null && echo thumb', "sh", path, thumb]);
  }

  Command {
    id: probe

    property string target: ""
    property string thumb: ""
    property int seconds: 0

    label: "recording thumbnail"
    // A missing ffmpeg still leaves a card, just without its picture.
    logFailures: false

    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n");
        root.add({
          path: probe.target,
          kind: "recording",
          bytes: parseInt(lines[0], 10) || 0,
          width: 0,
          height: 0,
          seconds: probe.seconds,
          thumb: lines.indexOf("thumb") !== -1 ? probe.thumb : "",
          note: "Saved"
        });
      }
    }
  }

  // ---- shared formatting ----

  function sizeLabel(bytes) {
    if (bytes >= 1048576)
      return (bytes / 1048576).toFixed(1) + " MB";
    if (bytes >= 1024)
      return Math.round(bytes / 1024) + " KB";
    return bytes + " B";
  }

  function durationLabel(seconds) {
    var m = Math.floor(seconds / 60);
    var s = seconds % 60;
    return m + ":" + (s < 10 ? "0" : "") + s;
  }
}
