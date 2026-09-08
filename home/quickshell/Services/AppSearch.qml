pragma Singleton

import QtQuick
import Quickshell

// Ranked desktop-entry search, behind the launcher.
//
// The ranking is a ladder, not a score. A query that starts the name beats one
// that starts a later word, which beats one that spells the initials, which
// beats a match anywhere in the name, which beats a match found only in the
// description or the keywords. Inside a rung entries keep their alphabetical
// order, so the list never reshuffles for a reason the query does not explain.
Singleton {
  id: root

  property string query: ""

  // Everything the menu is allowed to show, in name order, resolved once.
  // Ranking then only has to reorder this rather than re-read the entries.
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

  // Every match, not a screenful. Theme.launcherMaxRows caps how tall the
  // panel is allowed to grow, and the list scrolls past that; it must not also
  // decide how many applications exist.
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

  // What a row shows under the name. The generic name says what the thing is;
  // the comment says what it does. Prefer the sentence over the label.
  function describe(entry) {
    if (!entry)
      return "";
    if (entry.comment)
      return String(entry.comment);
    if (entry.genericName)
      return String(entry.genericName);
    return "";
  }

  // An entry names its icon the way the icon theme does, not the way a URL
  // does. Handing that name straight to an Image resolves it against the
  // component's own path and finds nothing, so it has to go through the theme
  // lookup first; `check` makes a name the theme cannot place come back empty
  // rather than as a broken path, which is what lets a row fall back to its
  // tinted initial. An entry that names an absolute file is used as it is.
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
