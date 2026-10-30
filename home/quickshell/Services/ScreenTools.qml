pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Capture/Colour.js" as Colour

// What the screen tools do once a tool is chosen (Capture/ScreenTools.qml draws them): read
// the text in a region, decode a QR code, pick a colour. Region and window grabs are handed
// to Captures. Each tool runs after its surface is off the screen, and raises `resulted` for
// it to come back with the answer.
Singleton {
  id: root

  readonly property var tools: [
    {
      key: "region",
      label: "Region",
      path: IconPaths.crop,
      keycap: "R"
    },
    {
      key: "window",
      label: "Window",
      path: IconPaths.appWindow,
      keycap: "W"
    },
    {
      key: "screen",
      label: "Screen",
      path: IconPaths.monitor,
      keycap: "S"
    },
    {
      key: "text",
      label: "Text",
      path: IconPaths.scanText,
      keycap: "T"
    },
    {
      key: "qr",
      label: "QR code",
      path: IconPaths.qrCode,
      keycap: "Q"
    },
    {
      key: "colour",
      label: "Colour",
      path: IconPaths.pipette,
      keycap: "C"
    }
  ]

  // The tool the row was last left on, so the next open starts there.
  property int last: 0

  // "idle", "picking" (slurp or the picker is up), "working".
  property string state: "idle"
  readonly property bool busy: state !== "idle"

  // The answer: which card to draw ("text", "qr", "colour", or "none" when nothing was found).
  property string resultKind: ""
  property string missing: ""

  property string text: ""
  property var codes: []
  property int codeIndex: 0
  property string colour: "#000000"
  property var history: []

  signal resulted(string kind)

  // ---- running a tool ----

  function run(key) {
    if (key === "region" || key === "window")
      Captures.begin(key);
    else if (key === "screen")
      Captures.begin("output");
    else if (key === "text")
      root.pickRegion("text");
    else if (key === "qr")
      root.pickRegion("qr");
    else if (key === "colour")
      root.pickColour();
  }

  // From a shortcut: the same as choosing the tool in the surface, which is closed first if it
  // is up, and given time to be gone before the grab.
  function start(key) {
    if (Bus.surfaceOpen("screentools")) {
      Bus.closeSurface("screentools");
      startLater.key = key;
      startLater.restart();
    } else {
      root.run(key);
    }
  }

  Timer {
    id: startLater

    property string key: ""

    interval: Theme.actionSettleDelay
    onTriggered: root.run(key)
  }

  property string job: ""
  property string geometry: ""

  function pickRegion(job) {
    if (root.busy)
      return;
    root.job = job;
    root.state = "picking";
    region.exec(["slurp"]);
  }

  Command {
    id: region

    label: "screen tools region"
    logFailures: false

    stdout: StdioCollector {
      onStreamFinished: {
        var g = text.trim();
        // Escape in slurp: nothing asked for, nothing to say.
        if (g === "") {
          root.state = "idle";
          return;
        }
        root.geometry = g;
        root.work();
      }
    }

    onFailed: root.state = "idle"
  }

  // A click without a drag is a region with no size, which for the QR reader means the whole
  // output: nothing dragged, so look at everything.
  function degenerate(g) {
    var m = g.match(/(\d+)x(\d+)$/);
    return m !== null && (parseInt(m[1], 10) < 3 || parseInt(m[2], 10) < 3);
  }

  function work() {
    root.state = "working";
    var grab = 'f=$(mktemp --suffix=.png) || exit 1; trap \'rm -f "$f"\' EXIT; ' + 'if [ -n "$1" ]; then grim -g "$1" "$f"; elif [ -n "$2" ]; then grim -o "$2" "$f"; else grim "$f"; fi || exit 1; ';
    if (root.job === "text") {
      // The result is also put on the clipboard here, before the card says so.
      grabber.exec(["sh", "-c", grab + 't=$(tesseract "$f" stdout -l eng 2>/dev/null | tr -d "\\f"); ' + 'printf %s "$t" | wl-copy > /dev/null 2>&1; printf %s "$t"', "sh", root.geometry, ""]);
    } else {
      var whole = root.degenerate(root.geometry);
      grabber.exec(["sh", "-c", grab + 'zbarimg -q --xml "$f"; true', "sh", whole ? "" : root.geometry, whole ? Monitors.focusedName : ""]);
    }
  }

  Command {
    id: grabber

    label: "screen tools"
    // tesseract and zbarimg say nothing useful on stderr that the card does not.
    logFailures: false

    stdout: StdioCollector {
      onStreamFinished: {
        var out = text;
        root.state = "idle";
        if (root.job === "text")
          root.finishText(out);
        else
          root.finishQr(out);
      }
    }

    onFailed: function (code, message) {
      root.state = "idle";
      console.warn("screen tools: grab failed (" + code + ")" + (message !== "" ? ": " + message : ""));
    }
  }

  // ---- text ----

  function finishText(out) {
    var t = out.replace(/[ \t]+\n/g, "\n").trim();
    if (t === "") {
      root.missing = "text";
      root.resultKind = "none";
    } else {
      root.text = t;
      root.resultKind = "text";
    }
    root.resulted(root.resultKind);
  }

  // "190 characters · 3 sentences · English"
  readonly property string textDetail: {
    var chars = root.text.length;
    var sentences = root.text.split(/[.!?]+(?:\s|$)/).filter(function (s) {
      return s.trim() !== "";
    }).length;
    return chars + (chars === 1 ? " character" : " characters") + " · " + sentences + (sentences === 1 ? " sentence" : " sentences") + " · English";
  }

  // Search the text on the web (the Helium window), a first line's worth of it.
  function search() {
    var q = root.text.replace(/\s+/g, " ").trim().substring(0, 300);
    open_.exec(["helium", "https://duckduckgo.com/?q=" + encodeURIComponent(q)]);
  }

  // The launcher, opened on a Claude chat that has already been asked.
  function askClaude() {
    Omnibox.pendingAsk = root.text;
    Bus.toggleSurface("launcher");
  }

  // ---- QR codes ----

  function finishQr(out) {
    var found = [];
    var re = /<data><!\[CDATA\[([\s\S]*?)\]\]><\/data>/g;
    var m;
    while ((m = re.exec(out)) !== null)
      found.push(m[1]);
    if (found.length === 0) {
      root.missing = "QR code";
      root.resultKind = "none";
    } else {
      root.codes = found;
      root.codeIndex = 0;
      root.resultKind = "qr";
    }
    root.resulted(root.resultKind);
  }

  readonly property string code: root.codes.length > 0 ? root.codes[Math.min(root.codeIndex, root.codes.length - 1)] : ""

  // What the payload is, for the header: the pill ("URL"), the description ("Link · host"),
  // and whether Open means anything for it.
  readonly property var codeInfo: root.describeCode(root.code)

  function describeCode(s) {
    var url = /^(https?):\/\/([^\/?#:]+)/i.exec(s);
    if (url)
      return {
        tag: "URL",
        what: "Link · " + url[2].replace(/^www\./, ""),
        openable: true
      };
    if (/^mailto:/i.test(s))
      return {
        tag: "Email",
        what: "Email · " + s.replace(/^mailto:/i, "").split("?")[0],
        openable: true
      };
    if (/^tel:/i.test(s))
      return {
        tag: "Phone",
        what: "Phone · " + s.replace(/^tel:/i, ""),
        openable: true
      };
    if (/^WIFI:/i.test(s)) {
      var ssid = /S:((?:\\.|[^;])*)/.exec(s);
      return {
        tag: "Wi‑Fi",
        what: "Wi‑Fi" + (ssid ? " · " + ssid[1] : ""),
        openable: false
      };
    }
    if (/^(BEGIN:VCARD|MECARD:)/i.test(s))
      return {
        tag: "Contact",
        what: "Contact",
        openable: false
      };
    return {
      tag: "Text",
      what: "Text · " + s.length + (s.length === 1 ? " character" : " characters"),
      openable: false
    };
  }

  function stepCode(delta) {
    if (root.codes.length > 1)
      root.codeIndex = ((root.codeIndex + delta) % root.codes.length + root.codes.length) % root.codes.length;
  }

  function openCode() {
    if (root.codeInfo.openable)
      open_.exec(["xdg-open", root.code]);
  }

  // ---- colour ----

  // The picker toggles: asked again while it is up, it is put away.
  function pickColour() {
    if (picker.running) {
      picker.running = false;
      return;
    }
    if (root.busy)
      return;
    root.state = "picking";
    // -a puts the hex on the clipboard the moment it is picked, so closing at once is complete.
    picker.exec(["hyprpicker", "-a"]);
  }

  Command {
    id: picker

    label: "hyprpicker"
    logFailures: false

    stdout: StdioCollector {
      onStreamFinished: {
        var hex = Colour.normalise(text.trim());
        root.state = "idle";
        if (hex === "")
          return;
        root.setColour(hex);
        root.resultKind = "colour";
        root.resulted("colour");
      }
    }

    onFailed: root.state = "idle"
  }

  // Becomes the current colour and goes to the front of the history, without a second copy.
  function setColour(hex) {
    root.colour = hex;
    var next = [hex].concat(root.history.filter(function (h) {
      return h !== hex;
    }));
    root.history = next.slice(0, Theme.colourHistoryCount);
    store.setText(JSON.stringify(root.history));
  }

  readonly property var formats: Colour.formats(root.colour)

  FileView {
    id: store

    path: Paths.stateDir + "/colours.json"
    printErrors: false

    onLoaded: {
      try {
        var list = JSON.parse(store.text());
        root.history = list.map(Colour.normalise).filter(function (h) {
          return h !== "";
        }).slice(0, Theme.colourHistoryCount);
        if (root.history.length > 0)
          root.colour = root.history[0];
      } catch (e) {
        root.history = [];
      }
    }
  }

  // ---- shared ----

  function copy(value) {
    clip.exec(["sh", "-c", 'printf %s "$1" | wl-copy > /dev/null 2>&1', "sh", value]);
  }

  Command {
    id: clip

    label: "copy"
  }

  Command {
    id: open_

    label: "open"
  }
}
