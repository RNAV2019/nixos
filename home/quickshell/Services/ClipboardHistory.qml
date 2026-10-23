pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Fuzzy.js" as Fuzzy

// cliphist's history, an Omnibox provider. Scoped (the "Clipboard History" row, or a
// leading '@') it lists recent clips and fuzzy-filters them; unscoped it only offers a
// few clips that plainly contain the query, under the apps. Return copies a clip back,
// Shift+Return deletes it. The history is read when the launcher opens, not polled.
Singleton {
  id: root

  property string query: ""
  property bool scoped: false

  readonly property string section: "Clipboard"
  readonly property string prefix: "@"
  readonly property string scopeGlyph: Icons.clipboard
  readonly property string hint: "Search clipboard…"

  readonly property int listLimit: 200
  readonly property int unscopedLimit: 3
  // Decoding costs a process per clip, so only the newest are described and thumbnailed;
  // both are cached by id, which never changes what it names, so later opens cost nothing.
  readonly property int detailLimit: 50
  readonly property int thumbLimit: 12
  readonly property string thumbDir: Paths.home + "/.cache/quickshell/cliphist"

  // Scores on Omnibox's scale. The entry row is strong so "clip" then Return opens it;
  // unscoped clips stay well below 60.
  readonly property int entryScore: 80
  readonly property int clipScore: 30

  // Newest first: { id, line, preview, lower, image, kind, size, width, height }
  property var entries: []
  // id -> { lines, chars, first }, for text clips.
  property var details: ({})
  // id -> file path, for image clips.
  property var thumbs: ({})

  readonly property bool launcherOpen: Bus.ownerOf("launcher") !== ""

  onLauncherOpenChanged: {
    if (launcherOpen)
      refresh();
  }
  onScopedChanged: {
    if (scoped)
      refresh();
  }

  function refresh() {
    list.run();
  }

  readonly property var entryRow: ({
      id: "clipboard:history",
      name: "Clipboard History",
      desc: "Copy back or delete something you copied",
      icon: "",
      glyph: Icons.clipboard,
      swatch: "",
      opensScope: true
    })

  readonly property var entryWords: ["clipboard", "clip", "paste", "history"]

  // Every word typed must start one of the entry words: "clip", "paste hist".
  function entryMatch(q) {
    var words = q.split(/\s+/);
    var all = words.every(function (w) {
      return root.entryWords.some(function (k) {
        return k.startsWith(w);
      });
    });
    var fz = Fuzzy.match(q, root.entryRow.name);
    if (all && q.length >= 3)
      return {
        score: root.entryScore + (fz ? fz.score * 10 : 0),
        positions: fz ? fz.positions : []
      };
    if (fz && q.length >= 3 && fz.score >= 0.3)
      return {
        score: 20 + fz.score * 10,
        positions: fz.positions
      };
    return null;
  }

  // Whitespace collapsed the way cliphist previews it, so the first line is a prefix of
  // the preview and a preview match can highlight inside the name.
  function collapse(s) {
    return String(s).replace(/\s+/g, " ").trim();
  }

  function parse(line) {
    var tab = line.indexOf("\t");
    if (tab < 0)
      return null;
    var preview = line.substr(tab + 1);
    var e = {
      id: line.substr(0, tab),
      line: line,
      preview: preview,
      lower: preview.toLowerCase(),
      image: false
    };
    var bin = preview.match(/^\[\[ binary data ([\d.]+ \w+)(?: (\w+))?(?: (\d+)x(\d+))? \]\]$/);
    if (bin) {
      e.image = !!bin[3];
      e.size = bin[1];
      e.kind = bin[2] || "";
      e.width = bin[3] || "";
      e.height = bin[4] || "";
      e.lower = root.binaryName(e).toLowerCase();
    }
    return e;
  }

  function binaryName(e) {
    if (!e.image)
      return "Binary data" + (e.kind ? " · " + e.kind.toUpperCase() : "");
    return "Image " + e.width + "×" + e.height + (e.kind ? " · " + e.kind.toUpperCase() : "");
  }

  function count(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  }

  function rowFor(e, score, positions) {
    var name, desc, icon = "", glyph = "";
    if (e.size) {
      name = root.binaryName(e);
      desc = e.size;
      icon = root.thumbs[e.id] ? "file://" + root.thumbs[e.id] : "";
      glyph = Icons.image;
    } else {
      var d = root.details[e.id];
      name = (d && d.first ? root.collapse(d.first) : e.preview).substr(0, 160);
      desc = d ? count(d.lines) + (d.lines === 1 ? " line · " : " lines · ") + count(d.chars) + (d.chars === 1 ? " character" : " characters") : "Text";
    }
    return {
      id: "clip:" + e.id,
      clipId: e.id,
      clipLine: e.line,
      name: name,
      desc: desc,
      icon: icon,
      glyph: glyph,
      swatch: "",
      score: score,
      matches: (positions || []).filter(function (p) {
        return p < name.length;
      })
    };
  }

  function run(start, length) {
    var out = [];
    for (var i = 0; i < length; i++)
      out.push(start + i);
    return out;
  }

  function wordStart(text, i) {
    return i === 0 || Fuzzy.SEPARATORS.indexOf(text.charAt(i - 1)) >= 0;
  }

  // Scoped: a substring leads, at a word start more; otherwise a fuzzy match on the
  // preview's head. Ties keep history order.
  function scopedMatch(e, q) {
    var at = e.lower.indexOf(q);
    if (at >= 0)
      return {
        score: 70 + (at === 0 ? 15 : root.wordStart(e.lower, at) ? 8 : 0),
        positions: e.size ? [] : run(at, q.length)
      };
    var fz = Fuzzy.match(q, e.size ? root.binaryName(e) : e.preview);
    if (fz && fz.score >= 0.1)
      return {
        score: 20 + fz.score * 40,
        positions: e.size ? [] : fz.positions
      };
    return null;
  }

  readonly property var emptyResults: {
    if (!root.scoped)
      return [];
    return root.entries.map(function (e) {
      return root.rowFor(e, 0, []);
    });
  }

  readonly property var results: {
    var q = root.query.trim().toLowerCase();
    if (q.length === 0)
      return [];
    var out = [];
    var i, hit;

    if (root.scoped) {
      for (i = 0; i < root.entries.length; i++) {
        hit = root.scopedMatch(root.entries[i], q);
        if (hit)
          out.push(root.rowFor(root.entries[i], hit.score, hit.positions));
      }
      return out;
    }

    var entry = root.entryMatch(q);
    if (entry)
      out.push(Object.assign({}, root.entryRow, {
        score: entry.score,
        matches: entry.positions
      }));

    // Three letters before a clip is offered, and only as a plain substring: scattered
    // letters match most of a history.
    if (q.length < 3)
      return out;
    var clips = [];
    for (i = 0; i < root.entries.length && clips.length < root.unscopedLimit; i++) {
      var e = root.entries[i];
      var at = e.lower.indexOf(q);
      if (at < 0)
        continue;
      var start = root.wordStart(e.lower, at);
      clips.push(root.rowFor(e, root.clipScore + (at === 0 ? 8 : start ? 4 : 0), e.size ? [] : run(at, q.length)));
    }
    return out.concat(clips);
  }

  function activate(row, modifiers) {
    if (row.opensScope) {
      // Until Omnibox scopes without a prefix, typing the prefix does the same.
      if (Omnibox.enterScope)
        Omnibox.enterScope(root);
      else
        Omnibox.setQuery(root.prefix);
      return true;
    }
    if (modifiers & Qt.ShiftModifier) {
      remove.exec(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", row.clipLine]);
      return true;
    }
    // The id goes in as an argument, never into the script text.
    Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", row.clipId]);
    return false;
  }

  QueuedProcess {
    id: list

    command: ["sh", "-c", 'cliphist -preview-width 300 list | head -n "$1"', "sh", String(root.listLimit)]

    stdout: StdioCollector {
      onStreamFinished: root.load(text)
    }
  }

  function load(text) {
    var lines = text.split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var e = lines[i].length > 0 ? root.parse(lines[i]) : null;
      if (e)
        out.push(e);
    }
    root.entries = out;

    var want = [], imgs = [], keep = [];
    for (var j = 0; j < out.length; j++) {
      keep.push(out[j].id);
      if (!out[j].size && !root.details[out[j].id] && want.length < root.detailLimit)
        want.push(out[j].id);
      if (out[j].image && imgs.length < root.thumbLimit)
        imgs.push(out[j].id + ":" + (out[j].kind || "img"));
    }
    if (want.length > 0) {
      describe.command = ["sh", "-c", 'for id; do cliphist decode "$id" | awk -v id="$id" \'NF && f == "" { f = substr($0, 1, 200) } { c += length($0) + 1 } END { if (NR) printf "%s\\t%d\\t%d\\t%s\\n", id, NR, c - 1, f }\'; done', "sh"].concat(want);
      describe.run();
    }
    thumbnail.command = ["sh", "-c", root.thumbScript, "sh", root.thumbDir, keep.join(" "), String(Theme.launcherIconSize * 4)].concat(imgs);
    thumbnail.run();
  }

  // Line and character counts and the first non-blank line, which the collapsed preview
  // cannot give. C.UTF-8 so awk counts characters, not bytes.
  QueuedProcess {
    id: describe

    environment: ({
        LC_ALL: "C.UTF-8"
      })

    stdout: StdioCollector {
      onStreamFinished: {
        var next = Object.assign({}, root.details);
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].split("\t");
          if (f.length < 4)
            continue;
          next[f[0]] = {
            lines: parseInt(f[1], 10),
            chars: parseInt(f[2], 10),
            first: f.slice(3).join("\t")
          };
        }
        root.details = next;
      }
    }
  }

  // Decodes each image once and shrinks it to the tile's source size, since the row loads
  // icons synchronously and a full screenshot would stall the list. Without the
  // thumbnailer the decoded image is used as it is. Files for clips gone from the
  // history are removed. Prints "<id>\t<path>" for every thumbnail on disk.
  readonly property string thumbScript: ['d=$1; keep=$2; size=$3; shift 3; mkdir -p "$d" || exit 1', 'for f in "$d"/*; do', '  [ -e "$f" ] || continue', '  n=${f##*/}', '  case " $keep " in *" ${n%%.*} "*) ;; *) rm -f "$f" ;; esac', 'done', 't=$(command -v gdk-pixbuf-thumbnailer || echo /usr/bin/gdk-pixbuf-thumbnailer)', 'for a; do', '  id=${a%%:*}; ext=${a#*:}', '  for f in "$d/$id.png" "$d/$id.$ext"; do', '    [ -s "$f" ] && { printf "%s\\t%s\\n" "$id" "$f"; continue 2; }', '  done', '  cliphist decode "$id" > "$d/$id.part" || { rm -f "$d/$id.part"; continue; }', '  if [ -x "$t" ] && "$t" -s "$size" "$d/$id.part" "$d/$id.png" 2>/dev/null; then', '    rm -f "$d/$id.part"; f="$d/$id.png"', '  else', '    f="$d/$id.$ext"; mv "$d/$id.part" "$f"', '  fi', '  printf "%s\\t%s\\n" "$id" "$f"', 'done'].join("\n")

  QueuedProcess {
    id: thumbnail

    stdout: StdioCollector {
      onStreamFinished: {
        var next = {};
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].split("\t");
          if (f.length === 2)
            next[f[0]] = f[1];
        }
        root.thumbs = next;
      }
    }
  }

  Command {
    id: remove

    label: "cliphist delete"
    onExited: root.refresh()
  }
}
