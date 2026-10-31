pragma Singleton

import QtQuick
import Quickshell
import "../Commons/Fuzzy.js" as Fuzzy

// Ranked desktop-entry search, an Omnibox provider. The old ladder (name prefix, word
// prefix, initials, substring) sets the band a match lands in; the fuzzy score orders
// within it, so a prefix still beats any scattered match. Keywords and generic names
// match below every name match and highlight nothing.
Singleton {
  id: root

  property string query: ""

  readonly property string section: "Applications"
  readonly property string prefix: ""

  // Everything the menu may show, in name order, resolved once with the bits every
  // keystroke would otherwise recompute.
  readonly property var entries: {
    var all = DesktopEntries.applications.values;
    var out = [];
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (e.noDisplay || !e.name)
        continue;
      var name = String(e.name);
      out.push({
        entry: e,
        id: String(e.id),
        name: name,
        lower: name.toLowerCase(),
        aside: [e.genericName, e.keywords].join(" ").toLowerCase(),
        comment: [e.comment, e.categories].join(" ").toLowerCase(),
        desc: describe(e),
        icon: iconFor(e)
      });
    }
    out.sort(function (a, b) {
      return a.name.localeCompare(b.name);
    });
    return out;
  }

  readonly property var emptyResults: entries.map(function (item) {
    return root.rowFor(item, 0, []);
  })

  // Every match; Theme.launcherMaxRows caps the panel height, not the result count.
  readonly property var results: {
    var q = query.trim().toLowerCase();
    if (q.length === 0)
      return [];

    var ranked = [];
    for (var i = 0; i < entries.length; i++) {
      var hit = match(entries[i], q);
      if (hit)
        ranked.push({
          hit: hit,
          order: i
        });
    }

    ranked.sort(function (a, b) {
      return b.hit.score - a.hit.score || a.order - b.order;
    });

    return ranked.map(function (r) {
      return root.rowFor(root.entries[r.order], r.hit.score, r.hit.positions);
    });
  }

  function rowFor(item, score, positions) {
    return {
      id: "app:" + item.id,
      desktopId: item.id,
      name: item.name,
      desc: item.desc,
      icon: item.icon,
      glyph: "",
      swatch: "",
      score: score,
      matches: positions
    };
  }

  function run(start, length) {
    var out = [];
    for (var i = 0; i < length; i++)
      out.push(start + i);
    return out;
  }

  // Bands on Omnibox's 0-100 scale: name prefix 80, word prefix 65, initials 55,
  // substring 45, scattered 20, keyword 15, comment 10; fuzzy quality adds up to 10.
  function match(item, q) {
    var name = item.lower;
    var fz = Fuzzy.match(q, item.name);
    var quality = fz ? fz.score * 10 : 0;
    var exact = name === q ? 10 : 0;

    if (name.startsWith(q))
      return {
        score: 80 + quality + exact,
        positions: run(0, q.length)
      };

    // Word starts, as the matcher sees them.
    var starts = [];
    for (var i = 1; i < name.length; i++) {
      if (Fuzzy.SEPARATORS.indexOf(name.charAt(i - 1)) >= 0 && Fuzzy.SEPARATORS.indexOf(name.charAt(i)) < 0)
        starts.push(i);
    }
    for (var j = 0; j < starts.length; j++) {
      if (name.substr(starts[j]).startsWith(q))
        return {
          score: 65 + quality,
          positions: run(starts[j], q.length)
        };
    }

    // "anc" should find Advanced Network Configuration.
    if (starts.length > 0 && q.length > 1) {
      var initials = name.charAt(0);
      var at = [0];
      for (var k = 0; k < starts.length; k++) {
        initials += name.charAt(starts[k]);
        at.push(starts[k]);
      }
      if (initials.startsWith(q))
        return {
          score: 55 + quality,
          positions: at.slice(0, q.length)
        };
    }

    var sub = name.indexOf(q);
    if (sub >= 0)
      return {
        score: 45 + quality,
        positions: run(sub, q.length)
      };

    // A scattered match needs some shape to it: one or two letters, or letters strewn
    // mid-word, find nearly everything.
    if (fz && q.length >= 3 && fz.score >= 0.2)
      return {
        score: 20 + quality,
        positions: fz.positions
      };

    if (item.aside.indexOf(q) >= 0)
      return {
        score: 15,
        positions: []
      };
    if (item.comment.indexOf(q) >= 0)
      return {
        score: 10,
        positions: []
      };
    return null;
  }

  // Prefer the comment's sentence over the generic name.
  function describe(entry) {
    if (!entry)
      return "";
    if (entry.comment)
      return String(entry.comment);
    if (entry.genericName)
      return String(entry.genericName);
    return "";
  }

  // Icon names are theme names, not URLs, so they go through the theme lookup; `check`
  // makes an unknown name come back empty. Absolute paths are used as they are.
  function iconFor(entry) {
    if (!entry || !entry.icon)
      return "";
    var name = String(entry.icon);
    if (name.startsWith("/"))
      return "file://" + name;
    return Quickshell.iconPath(name, true);
  }

  function launch(id) {
    var entry = DesktopEntries.byId(id);
    if (entry)
      Launch.entry(entry);
  }

  function activate(row, modifiers) {
    launch(row.desktopId);
    return false;
  }
}
