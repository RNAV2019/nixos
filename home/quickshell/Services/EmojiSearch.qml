pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Fuzzy.js" as Fuzzy
import "../Commons/Symbols.js" as Symbols

// Emoji and symbols, an Omnibox provider. Emoji come from a table Nix builds out of
// Unicode's emoji-test.txt and the CLDR keywords (pkgs/quickshell-emoji), linked into
// ~/.local/share/quickshell; symbols from Commons/Symbols.js, so they work without it.
// Unscoped it offers a few close matches under the apps and a row that opens the picker;
// scoped (that row, or a leading ':') it searches everything. Return copies; Shift+Return
// also types the character into the window the launcher hands focus back to.
Singleton {
  id: root

  property string query: ""
  property bool scoped: false

  readonly property string section: "Emoji & Symbols"
  readonly property string prefix: ":"
  readonly property string scopeGlyph: Icons.emoji
  readonly property string hint: "Search emoji and symbols…"

  // QS_EMOJI_DATA points at another table, for testing before a rebuild links this one.
  readonly property string dataPath: Quickshell.env("QS_EMOJI_DATA") || (Quickshell.env("XDG_DATA_HOME") || Paths.home + "/.local/share") + "/quickshell/emoji.tsv"

  // Parsed emoji, in Unicode's order; empty until the table loads, or if it is missing.
  property var emoji: []

  readonly property var symbols: {
    var out = [];
    for (var g = 0; g < Symbols.GROUPS.length; g++) {
      var group = Symbols.GROUPS[g];
      for (var i = 0; i < group.items.length; i++) {
        var s = group.items[i];
        out.push(entry(s[0], s[1], group.name, s[2].split(", "), true));
      }
    }
    return out;
  }

  // Symbols first: a query like "arrow" wants → before 🏹. An emoji that is also a symbol
  // is dropped, so the symbol's text presentation (™, ↔) wins.
  readonly property var items: {
    var seen = {};
    for (var i = 0; i < symbols.length; i++)
      seen[symbols[i].char] = true;
    return symbols.concat(emoji.filter(function (e) {
      return !seen[e.char.replace(/️/g, "")];
    }));
  }

  readonly property var byChar: {
    var map = {};
    for (var i = 0; i < items.length; i++)
      map[items[i].char] = items[i];
    return map;
  }

  // The scoped empty list starts here.
  readonly property var favourites: ["😂", "❤️", "👍", "🙏", "😭", "😊", "🔥", "✨", "🎉", "😅", "🤔", "👀", "✅", "💯", "🥲", "😍", "🙌", "👋", "😎", "🤝", "💀", "🫠"]
  // A one-letter scoped query matches most of the table; the list never needs all of it.
  readonly property int scopedLimit: 80
  readonly property int unscopedLimit: 4

  // Unscoped scores sit under the apps' strong 60, so a close emoji never outranks an app
  // by name; an exact name ("pi") may beat a weak app match.
  readonly property int exactScore: 58
  readonly property int nearScore: 35

  readonly property var entryRow: ({
      id: "emoji-search",
      name: "Search Emoji & Symbols",
      desc: "Emoji, arrows, maths, keyboard and Greek",
      icon: "",
      glyph: Icons.emoji,
      swatch: "",
      score: 0,
      matches: [],
      opensScope: true
    })
  readonly property var entryWords: ["emoji", "emojis", "emoticon", "emoticons", "symbol", "symbols"]

  // Never shown for the empty unscoped query, so emoji stay out of the launcher's front page.
  readonly property var emptyResults: {
    if (!scoped)
      return [];
    var out = [];
    var taken = {};
    var add = function (item) {
      if (item && !taken[item.char]) {
        taken[item.char] = true;
        out.push(root.rowFor(item, 0, []));
      }
    };
    for (var j = 0; j < favourites.length; j++)
      add(byChar[favourites[j]]);
    for (var k = 0; k < symbols.length; k++)
      add(symbols[k]);
    return out;
  }

  readonly property var results: {
    var q = query.trim().toLowerCase().replace(/\s+/g, " ");
    if (q.length === 0)
      return [];
    if (!scoped)
      return unscopedRows(q);

    var ranked = rank(q, true);
    return ranked.slice(0, scopedLimit).map(function (r) {
      return root.rowFor(r.item, r.band, r.positions);
    });
  }

  function entry(ch, name, group, keywords, symbol) {
    var lower = name.toLowerCase();
    var kw = keywords.filter(function (k) {
      return k.length > 0;
    }).map(function (k) {
      return k.toLowerCase();
    });
    return {
      char: ch,
      name: name.charAt(0).toUpperCase() + name.substr(1),
      lower: lower,
      starts: wordStarts(lower),
      keywords: kw,
      hay: lower + " " + kw.join(" "),
      desc: kw.length > 0 ? kw.slice(0, 6).join(", ") : group,
      favourite: favourites.indexOf(ch) >= 0 ? 1 : 0,
      symbol: symbol
    };
  }

  function wordStarts(name) {
    var starts = [0];
    for (var i = 1; i < name.length; i++) {
      if (Fuzzy.SEPARATORS.indexOf(name.charAt(i - 1)) >= 0 && Fuzzy.SEPARATORS.indexOf(name.charAt(i)) < 0)
        starts.push(i);
    }
    return starts;
  }

  function run(start, length) {
    var out = [];
    for (var i = 0; i < length; i++)
      out.push(start + i);
    return out;
  }

  // Bands: exact name 100, a whole word 85 ("joy" in "face with tears of joy"), the start
  // of the name 80 ("joystick"), of a later word 70, an exact keyword ("lol") 68, a keyword
  // prefix 55, every word found 50, a substring 45, and scoped only a scattered match from 20.
  function match(item, q, tokens, fuzzy) {
    var name = item.lower;
    if (name === q)
      return {
        band: 100,
        positions: run(0, q.length)
      };
    var prefixAt = -1;
    for (var i = 0; i < item.starts.length; i++) {
      var s = item.starts[i];
      if (name.substr(s, q.length) !== q)
        continue;
      var after = name.charAt(s + q.length);
      if (after === "" || Fuzzy.SEPARATORS.indexOf(after) >= 0)
        return {
          band: 85,
          positions: run(s, q.length)
        };
      if (prefixAt < 0)
        prefixAt = s;
    }
    if (prefixAt >= 0)
      return {
        band: prefixAt === 0 ? 80 : 70,
        positions: run(prefixAt, q.length)
      };
    if (item.keywords.indexOf(q) >= 0)
      return {
        band: 68,
        positions: []
      };
    for (var k = 0; k < item.keywords.length; k++) {
      if (item.keywords[k].startsWith(q))
        return {
          band: 55,
          positions: []
        };
    }
    if (tokens.length > 1) {
      var positions = [];
      var all = tokens.every(function (t) {
        for (var w = 0; w < item.starts.length; w++) {
          if (name.substr(item.starts[w], t.length) === t) {
            positions = positions.concat(root.run(item.starts[w], t.length));
            return true;
          }
        }
        return item.keywords.some(function (kw) {
          return kw.startsWith(t);
        });
      });
      if (all)
        return {
          band: 50,
          positions: positions
        };
    }
    var sub = name.indexOf(q);
    if (sub >= 0)
      return {
        band: 45,
        positions: run(sub, q.length)
      };
    if (fuzzy && q.length >= 2) {
      var fz = Fuzzy.match(q, item.name);
      if (fz && fz.score >= 0.3)
        return {
          band: 20 + Math.round(fz.score * 10),
          positions: fz.positions
        };
    }
    return null;
  }

  // Best band first; within one, a favourite ("heart" finds ❤️), then the plainer name with
  // fewer words ("red heart" over "heart with arrow"), then the table's order.
  function rank(q, fuzzy) {
    var tokens = q.split(" ");
    var ranked = [];
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      // Most rows share no word with the query at all; skip them before matching.
      if (!fuzzy && item.hay.indexOf(tokens[0]) < 0)
        continue;
      var hit = match(item, q, tokens, fuzzy);
      if (hit)
        ranked.push({
          item: item,
          band: hit.band,
          positions: hit.positions,
          order: i
        });
    }
    ranked.sort(function (a, b) {
      return b.band - a.band || b.item.favourite - a.item.favourite || a.item.starts.length - b.item.starts.length || a.order - b.order;
    });
    return ranked;
  }

  // A few close matches only: three letters and a word or keyword match, or an exact
  // name of two ("pi"). Then the row that opens the picker, if the query asks for it.
  function unscopedRows(q) {
    var out = [];
    if (q.length >= 2) {
      var ranked = rank(q, false);
      for (var i = 0; i < ranked.length && out.length < unscopedLimit; i++) {
        var r = ranked[i];
        if (r.band === 100 || (q.length >= 3 && r.band >= 68))
          out.push(rowFor(r.item, r.band === 100 ? exactScore : nearScore, r.positions));
      }
    }
    var open = entryMatch(q);
    if (open)
      out.unshift(Object.assign({}, entryRow, open));
    return out;
  }

  // "emo", "emoji", "symbols" find the picker; three letters make it a strong match.
  function entryMatch(q) {
    if (q.length < 2)
      return null;
    for (var i = 0; i < entryWords.length; i++) {
      var w = entryWords[i];
      if (!w.startsWith(q) && !q.startsWith(w))
        continue;
      var at = w.startsWith("sym") ? 15 : 7;
      var lit = w.startsWith("sym") ? Math.min(q.length, 7) : Math.min(q.length, w.startsWith("emoji") ? 5 : 3);
      return {
        score: q.length >= 3 ? 75 + Math.round(10 * Math.min(q.length, w.length) / w.length) : 45,
        matches: run(at, lit)
      };
    }
    return null;
  }

  function rowFor(item, score, positions) {
    return {
      id: "emoji:" + item.char,
      name: item.name,
      desc: item.desc,
      icon: "",
      // An emoji draws in its own colour on a neutral tile; a symbol is a glyph like any
      // other computed answer. `glyph` is set for both, for a launcher without `emoji`.
      emoji: item.symbol ? "" : item.char,
      glyph: item.char,
      swatch: "",
      score: score,
      matches: positions,
      copy: item.char
    };
  }

  // Paste is best-effort: wtype types into whatever has focus once the launcher has let it
  // go, and the close plus Hyprland's refocus fit well inside the delay.
  readonly property int pasteDelay: 250
  property bool canType: false

  function activate(row, modifiers) {
    if (row.opensScope) {
      if (typeof Omnibox.enterScope === "function")
        Omnibox.enterScope(root);
      else
        Omnibox.setQuery(root.prefix);
      return true;
    }
    Clipboard.copy(row.copy);
    if ((modifiers & Qt.ShiftModifier) && root.canType)
      Quickshell.execDetached(["sh", "-c", "sleep " + root.pasteDelay / 1000 + "; exec wtype -- \"$1\"", "sh", row.copy]);
    return false;
  }

  function parse(text) {
    var lines = text.split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].split("\t");
      if (f.length >= 3)
        out.push(entry(f[0], f[1], f[2], f[3] ? f[3].split(", ") : [], false));
    }
    root.emoji = out;
  }

  // Loaded off the keystroke path: read in the background at startup, parsed once.
  FileView {
    id: table

    path: root.dataPath
    printErrors: false
    watchChanges: true

    onLoaded: Qt.callLater(function () {
      root.parse(table.text());
    })
    onFileChanged: reload()
  }

  Process {
    command: ["sh", "-c", "command -v wtype"]
    running: true
    onExited: function (code) {
      root.canType = code === 0;
    }
  }
}
