pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

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

  readonly property int limit: Theme.launcherMaxRows

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

  readonly property var results: {
    var q = query.trim().toLowerCase();
    if (q.length === 0)
      return entries.slice(0, limit);

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
    for (var j = 0; j < ranked.length && j < limit; j++)
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

  function launch(id) {
    var entry = DesktopEntries.byId(id);
    if (entry)
      entry.execute();
  }
}
