import QtQuick
import Quickshell

// What a launcher provider is, and the helpers they all wrote for themselves. The contract
// the launcher relies on is documented in Omnibox.qml; a provider file takes this as its
// root type, since Singleton is the base here, and overrides what it has an answer for.
Singleton {
  id: root

  property string query: ""
  property bool scoped: false

  property string section: ""
  property string prefix: ""
  property string scopeGlyph: ""
  property string hint: ""

  property var results: []
  property var emptyResults: []

  // The row that opens this provider's scope from the unscoped list, and the words that call
  // it up. A provider with nothing to enter leaves both empty.
  property var entryRow: null
  property var entryWords: []

  // Act on a row; true keeps the launcher open. A provider that has its own rows calls
  // `enters` first.
  function activate(row, modifiers) {
    return root.enters(row);
  }

  // The positions start .. start + length - 1, for the highlight on a contiguous match.
  function run(start, length) {
    var out = [];
    for (var i = 0; i < length; i++)
      out.push(start + i);
    return out;
  }

  // A row with every field the launcher reads; `fields` says what differs from the blank one.
  function makeRow(fields) {
    return Object.assign({
      id: "",
      name: "",
      desc: "",
      icon: "",
      glyph: "",
      swatch: "",
      kind: "",
      score: 0,
      matches: []
    }, fields);
  }

  // Whether `row` opens this provider's scope, which it then does.
  function enters(row) {
    if (!row.opensScope)
      return false;
    Omnibox.enterScope(root);
    return true;
  }

  // How `q` calls up the entry row: { score, positions }, or null. The words a provider
  // answers to are its own.
  function entryMatch(q) {
    return null;
  }

  // The entry row scored for `q`, or null when `q` does not ask for it.
  function entryRowFor(q) {
    var hit = root.entryMatch(q);
    return hit ? Object.assign({}, root.entryRow, {
      score: hit.score,
      matches: hit.positions
    }) : null;
  }
}
