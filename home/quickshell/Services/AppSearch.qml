pragma Singleton

import QtQuick
import Quickshell

// Ranked desktop-entry search. The ranking is a ladder: name prefix, then word
// prefix, initials, substring, then description or keywords; ties stay alphabetical.
Singleton {
  id: root

  property string query: ""

  // Everything the menu may show, in name order, resolved once.
  readonly property var entries: {
    var all = DesktopEntries.applications.values;
    var out = [];
    for (var i = 0; i < all.length; i++) {
      if (!all[i].noDisplay && all[i].name)
        out.push(all[i]);
    }
    out.sort(function (a, b) {
      return a.name.localeCompare(b.name);
    });
    return out;
  }

  // Every match; Theme.launcherMaxRows caps the panel height, not the result count.
  readonly property var results: {
    var q = query.trim().toLowerCase();
    if (q.length === 0)
      return entries;

    var ranked = [];
    for (var i = 0; i < entries.length; i++) {
      var r = rank(entries[i], q);
      if (r >= 0)
        ranked.push({
          rank: r,
          order: i,
          entry: entries[i]
        });
    }

    ranked.sort(function (a, b) {
      return a.rank - b.rank || a.order - b.order;
    });

    var out = [];
    for (var j = 0; j < ranked.length; j++)
      out.push(ranked[j].entry);
    return out;
  }

  // The rung a query lands on, or -1 for no match at all.
  function rank(entry, q) {
    var name = String(entry.name || "").toLowerCase();
    if (name.startsWith(q))
      return 0;

    var words = name.split(/[\s\-_.:/]+/).filter(function (w) {
      return w.length > 0;
    });

    for (var i = 1; i < words.length; i++) {
      if (words[i].startsWith(q))
        return 1;
    }

    // "anc" should find Advanced Network Configuration.
    if (words.length > 1 && q.length > 1) {
      var initials = "";
      for (var j = 0; j < words.length; j++)
        initials += words[j].charAt(0);
      if (initials.startsWith(q))
        return 2;
    }

    if (name.indexOf(q) >= 0)
      return 3;

    var aside = [entry.genericName, entry.comment, entry.categories, entry.keywords].join(" ").toLowerCase();
    if (aside.indexOf(q) >= 0)
      return 4;

    return -1;
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
  // makes an unknown name come back empty rather than a broken path. Absolute paths
  // are used as they are.
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
      entry.execute();
  }
}
