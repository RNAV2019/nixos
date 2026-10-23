.pragma library

// Subsequence matching after fzy: every query character must appear in order, and the
// alignment that lands on word starts and consecutive runs wins. `match` returns
// { score, positions } with score in 0-1 (about 1 for a prefix or a run of word starts),
// or null when the query is not a subsequence at all.

var SEPARATORS = " -_.:/()[]+";
var MAX_TEXT = 64;
var MAX_QUERY = 32;

var GAP_LEADING = -0.005;
var GAP_TRAILING = -0.005;
var GAP_INNER = -0.01;
var CONSECUTIVE = 1.0;

// What landing on character i is worth: the very start most, then a word start, then a
// camelCase hump; mid-word nothing.
function bonusAt(text, i) {
  if (i === 0)
    return 1.0;
  var prev = text.charAt(i - 1);
  if (SEPARATORS.indexOf(prev) >= 0)
    return 0.9;
  var c = text.charAt(i);
  if (c !== c.toLowerCase() && prev !== prev.toUpperCase())
    return 0.7;
  return 0;
}

function match(query, text) {
  var q = String(query).toLowerCase();
  var full = String(text);
  var n = q.length;
  var m = Math.min(full.length, MAX_TEXT);
  if (n === 0)
    return {
      score: 0,
      positions: []
    };
  if (n > m || n > MAX_QUERY)
    return null;

  var t = full.substr(0, m).toLowerCase();
  var i, j, k = 0;

  // Most candidates fail here, before the table is built.
  for (j = 0; j < m && k < n; j++) {
    if (t.charAt(j) === q.charAt(k))
      k++;
  }
  if (k < n)
    return null;

  var bonus = [];
  for (j = 0; j < m; j++)
    bonus.push(bonusAt(full, j));

  // D: best score with query[i] matched exactly at j. M: best with query[0..i] placed
  // anywhere in text[0..j].
  var D = [], M = [];
  for (i = 0; i < n; i++) {
    D.push(new Array(m));
    M.push(new Array(m));
    var prev = -Infinity;
    var gap = i === n - 1 ? GAP_TRAILING : GAP_INNER;
    for (j = 0; j < m; j++) {
      if (q.charAt(i) === t.charAt(j)) {
        var s = -Infinity;
        if (i === 0)
          s = j * GAP_LEADING + bonus[j];
        else if (j > 0)
          s = Math.max(M[i - 1][j - 1] + bonus[j], D[i - 1][j - 1] + CONSECUTIVE);
        D[i][j] = s;
        prev = Math.max(s, prev + gap);
      } else {
        D[i][j] = -Infinity;
        prev = prev + gap;
      }
      M[i][j] = prev;
    }
  }

  // Walk back along the winning alignment; once inside a run, stay in it.
  var positions = new Array(n);
  var inRun = false;
  j = m - 1;
  for (i = n - 1; i >= 0; i--) {
    for (; j >= 0; j--) {
      if (D[i][j] !== -Infinity && (inRun || D[i][j] === M[i][j])) {
        inRun = i > 0 && j > 0 && M[i][j] === D[i - 1][j - 1] + CONSECUTIVE;
        positions[i] = j--;
        break;
      }
    }
  }

  return {
    score: Math.max(0, Math.min(1, M[n - 1][m - 1] / n)),
    positions: positions
  };
}
