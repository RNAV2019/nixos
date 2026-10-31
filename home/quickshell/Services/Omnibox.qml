pragma Singleton

import QtQuick
import Quickshell

// The launcher's search: one query fanned out to every provider, their rows merged into
// sections. The launcher only draws `results` and calls `activate`.
//
// A provider is a Singleton with:
//   property string query       Written here: the typed text when this provider holds
//                               the scope or none does; "" while another holds it.
//   property bool scoped        Optional; written here, true while this provider holds
//                               the scope. Set before `query`.
//   readonly property string section   Heading over its rows ("Applications"), and the
//                               chip's label in the search field while scoped.
//   readonly property string prefix     Optional hidden shortcut into the scope ("=" for the
//                               calculator); "" for none. Never needed: enterScope does the
//                               same from a row.
//   readonly property string scopeGlyph Optional; drawn in the scope chip.
//   readonly property string hint       Optional; the field's placeholder while scoped
//                               ("Search clipboard…").
//   property var results        Rows for a non-empty query, in the provider's own order.
//   property var emptyResults   Optional; rows for an empty query (apps list them all).
//   function activate(row, modifiers)   Act on a row; return true to keep the launcher
//                               open (a multi-step flow), false to close it.
//
// Scope. enterScope(provider) runs that provider alone: the field is cleared, the provider
// gets `scoped = true` and the typed text as its `query`, and the field carries a chip with
// its `scopeGlyph` and `section`. A typed `prefix` does the same and is consumed into the
// chip, so the field never shows it. leaveScope() returns to every provider, clearing the
// field. The launcher leaves the scope on Escape or on Backspace in an empty field.
//
// A row is a plain object:
//   { id, name, desc, icon, glyph, swatch, score, matches, ...anything else }
//   id       Unique across every provider ("app:firefox.desktop"), stable while the row
//            means the same thing: it keys diffing and animation.
//   name     The title. desc: the line under it ("" for one line).
//   icon     Image URL; else `glyph` (an Icons glyph on an accent tile); else `swatch` (a
//            colour); else the name's initial.
//   score    0-100. 60 and up is a strong match and may lift its section to the top: apps
//            put a name prefix at 80, the calculator a sum at 90.
//   matches  Indices into `name` the query matched, from Fuzzy.match; [] for none. The
//            launcher no longer draws them, but they stay part of a row.
// Rows come back to `activate` as they were given, plus `provider` and `rank`, so a
// provider can carry its own fields (`desktopId`, `copy`) through.
//
// Ordering: within a section by score (ties keep provider order); sections in `providers`
// order, except that the section with the best row is lifted to the top when that row is
// strong. Sections are an ordering only: the launcher draws no headings between them. An
// empty query shows each provider's `emptyResults`.
Singleton {
  id: root

  // Order is the default section order. Adding a provider is one entry here.
  readonly property var providers: [AppSearch, Calculator, ClipboardHistory, EmojiSearch]

  property string query: ""

  // The provider holding the scope, or null when every provider runs.
  property var scope: null

  // Flat, in display order.
  property var results: []

  readonly property int strongScore: 60

  signal queryRequested(string text)

  // For a provider's multi-step flow: puts `text` in the search field.
  function setQuery(text) {
    root.queryRequested(text);
    // Nothing drew the field (no launcher yet); keep the query in step anyway.
    if (root.query !== text)
      root.query = text;
  }

  function enterScope(provider) {
    root.scope = provider || null;
    root.setQuery("");
    root.dispatch();
  }

  function leaveScope() {
    root.scope = null;
    root.setQuery("");
    root.dispatch();
  }

  // Back to a fresh, unscoped launcher, as every open starts.
  function reset() {
    root.scope = null;
    root.setQuery("");
    root.dispatch();
  }

  onQueryChanged: dispatch()

  function dispatch() {
    var q = root.query;
    if (!root.scope) {
      var hit = null;
      for (var i = 0; i < providers.length; i++) {
        var p = providers[i];
        if (p.prefix && q.startsWith(p.prefix) && (!hit || p.prefix.length > hit.prefix.length))
          hit = p;
      }
      // The prefix is a shortcut into the chip: consumed, the rest stays typed.
      if (hit) {
        root.scope = hit;
        // setQuery writes the query, which comes back through here scoped.
        root.setQuery(q.substr(hit.prefix.length));
        return;
      }
    }
    root.fanOut();
  }

  function fanOut() {
    var q = root.query;
    var scope = root.scope;
    for (var j = 0; j < providers.length; j++) {
      var pj = providers[j];
      if (pj.scoped !== undefined)
        pj.scoped = pj === scope;
      pj.query = !scope || pj === scope ? q : "";
    }
    schedule();
  }

  // Providers answer in several property changes per keystroke, some later from a
  // process; merging once per event-loop pass keeps the launcher's diff to one.
  function schedule() {
    Qt.callLater(root.rebuild);
  }

  function decorate(row, provider) {
    return Object.assign({}, row, {
      provider: provider,
      rank: row.score || 0
    });
  }

  function rebuild() {
    var scope = root.scope;
    var blank = (scope ? scope.query : root.query).trim().length === 0;
    var taken = {};
    var sections = [];
    var i, j;

    for (i = 0; i < providers.length; i++) {
      var p = providers[i];
      if (scope && p !== scope)
        continue;
      var given = (blank ? p.emptyResults : p.results) || [];
      var rows = [];
      for (j = 0; j < given.length; j++) {
        // A repeated id would break the launcher's diff.
        if (taken[given[j].id])
          continue;
        taken[given[j].id] = true;
        var row = root.decorate(given[j], p);
        row.order = j;
        rows.push(row);
      }
      // The empty list stays in the provider's own (alphabetical) order.
      if (!blank)
        rows.sort(function (a, b) {
          return b.rank - a.rank || a.order - b.order;
        });
      if (rows.length > 0)
        sections.push({
          name: p.section,
          rows: rows
        });
    }

    if (!blank) {
      var best = -1;
      for (i = 0; i < sections.length; i++) {
        if (sections[i].rows[0].rank >= root.strongScore && (best < 0 || sections[i].rows[0].rank > sections[best].rows[0].rank))
          best = i;
      }
      if (best > 0)
        sections.unshift(sections.splice(best, 1)[0]);
    }

    var out = [];
    for (i = 0; i < sections.length; i++)
      out = out.concat(sections[i].rows);
    root.results = out;
  }

  // Hands the row to its provider. Returns whether to stay open.
  function activate(row, modifiers) {
    if (!row || !row.provider)
      return false;
    return row.provider.activate(row, modifiers || 0) === true;
  }

  Component.onCompleted: {
    for (var i = 0; i < providers.length; i++) {
      var p = providers[i];
      p.resultsChanged.connect(root.schedule);
      if (p.emptyResultsChanged)
        p.emptyResultsChanged.connect(root.schedule);
    }
    dispatch();
  }
}
