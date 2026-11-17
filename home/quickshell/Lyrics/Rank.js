.pragma library

// Which of the sheets the sources offered is the song that is playing, and which of those to
// show: Sonora's rules (its crates/music/src/lyrics/mod.rs and shape.rs), so the pill shows what
// its lyrics panel does. No QML imports: tools/lyrics-test.mjs evaluates this file under node.
//
// A query is the song as the player gives it: { title, artist, album, duration }, the length in
// seconds and 0 when unknown. A hit is Sheets.js's.

// The length a hit may differ by and still be the same recording, and by how much it is as
// good as the same.
var CLOSE_ENOUGH = 3;
var WAY_OFF = 10;
var TITLE = 40;
var ARTIST = 30;
var ALBUM = 15;
var SYNCED = 200;
var WORDED = 400;
var DRIFTED = 50;
var TRUNCATED = 500;
// A source that is the recording's own sheet rather than anybody's upload: its words are not
// re-cut to another sheet's lines.
var TRUSTED = 25;

// A letter or a digit, in any script: what a name is compared by. Asked of every character of
// every sheet, so each character is worked out once.
var LETTERS = {};

function letter(ch) {
  var known = LETTERS[ch];
  if (known === undefined) {
    known = /[0-9]/.test(ch) || ch.toLowerCase() !== ch.toUpperCase() || /[\u00aa\u00ba\u02b0-\u02ff\u0370-\u1fff\u2c00-\u2dff\u3040-\u312f\u3400-\u4dbf\u4e00-\u9fff\ua000-\ud7af\uf900-\ufaff\uff10-\uff19\uff66-\uffdc]/.test(ch);
    LETTERS[ch] = known;
  }
  return known;
}

// A name without what editions add to it: nothing after " - ", nothing in brackets, letters and
// digits only, in lower case.
function undecorated(text) {
  var t = String(text).split(" - ")[0];
  var depth = 0;
  var out = "";
  for (var i = 0; i < t.length; i++) {
    var ch = t.charAt(i);
    if (ch === "(" || ch === "[") {
      depth++;
    } else if (ch === ")" || ch === "]") {
      depth = Math.max(0, depth - 1);
    } else if (depth === 0 && letter(ch)) {
      out += ch.toLowerCase();
    }
  }
  return out;
}

// The same name, or one within the other and at least half of it.
function alike(left, right) {
  var a = undecorated(left), b = undecorated(right);
  if (a === "" || b === "")
    return false;
  if (a === b)
    return true;
  var short = a.length <= b.length ? a : b;
  var long = a.length <= b.length ? b : a;
  return long.indexOf(short) !== -1 && short.length * 2 >= long.length;
}

function artistNames(artists) {
  return String(artists).split(/[,&;]/).map(function (name) {
    return name.trim();
  }).filter(function (name) {
    return name !== "";
  });
}

// One shared name is enough for a collaboration.
function artistsAlike(left, right) {
  if (alike(left, right))
    return true;
  var a = artistNames(left), b = artistNames(right);
  return a.some(function (x) {
    return b.some(function (y) {
      return alike(x, y);
    });
  });
}

// Whether a hit is for the queried song at all: the same title and artist, and a length close
// enough when both are known. A different recording keeps different time, so it is no hit.
function matched(query, hit) {
  if (!alike(hit.title, query.title) || !artistsAlike(hit.artist, query.artist))
    return false;
  if (hit.duration === null || !(query.duration > 0))
    return true;
  return Math.abs(Math.floor(hit.duration) - Math.floor(query.duration)) <= WAY_OFF;
}

// From a sheet's first line to the end of its last.
function span(lines) {
  if (lines.length === 0)
    return 0;
  var last = lines[lines.length - 1];
  return Math.max(last.end !== null ? last.end : last.start, last.start);
}

// A sheet that stops well before the song does.
function truncated(hit, duration) {
  return duration > 0 && hit.lines.length > 0 && span(hit.lines) < duration * 0.6;
}

function stretchedShout(text) {
  // A shout has no small letters: nearly every line is out at once.
  if (/[a-z]/.test(text))
    return false;
  var upper = false, lower = false, previous = "", run = 0, longest = 0;
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i);
    if (ch.toLowerCase() === ch.toUpperCase())
      continue;
    if (ch === ch.toUpperCase())
      upper = true;
    else
      lower = true;
    var folded = ch.toLowerCase();
    if (folded === previous) {
      run++;
    } else {
      previous = folded;
      run = 1;
    }
    longest = Math.max(longest, run);
  }
  return upper && !lower && longest >= 3;
}

// A sheet somebody typed for effect: three lines or more, and one in six, of "AHHHHH!!!".
function lowQuality(hit) {
  var noisy = 0;
  hit.lines.forEach(function (line) {
    if (stretchedShout(line.text))
      noisy++;
  });
  return noisy >= 3 && noisy * 6 >= hit.lines.length;
}

function eligible(query, hit) {
  return matched(query, hit) && hit.lines.length > 0 && !lowQuality(hit);
}

function score(query, hit) {
  var s = hit.trust;
  if (hit.duration !== null) {
    var drift = Math.abs(Math.floor(hit.duration) - Math.floor(query.duration));
    if (drift <= CLOSE_ENOUGH)
      s += 100 - drift * 10;
    else if (drift > WAY_OFF)
      s -= DRIFTED;
  }
  if (alike(hit.title, query.title))
    s += TITLE;
  if (artistsAlike(hit.artist, query.artist))
    s += ARTIST;
  if (query.album && hit.album && alike(hit.album, query.album))
    s += ALBUM;
  if (hit.synced)
    s += SYNCED;
  if (hit.worded)
    s += WORDED;
  if (truncated(hit, query.duration))
    s -= TRUNCATED;
  return s;
}

// What kind of sheet a hit is: 2 timed and the length of the song, 0 one that stops early.
function grade(query, hit) {
  return truncated(hit, query.duration) ? 0 : 2;
}

// Timed, and running the length of the song: the best a source can offer, which only a source
// earlier in the order can better.
function fullySynced(query, hit) {
  return grade(query, hit) === 2;
}

// What two sheets share when they are the same lyrics.
function fingerprint(hit) {
  return (hit.worded ? "w:" : "l:") + hit.lines.map(function (line) {
    return line.text;
  }).join("").toLowerCase().replace(/[\s!-\/:-@\[-`{-~\u2000-\u206f\u3000-\u303f]+/g, "");
}

// The hits for the song, best first and without twins. A sheet the length of the song beats one
// cut short; then the source earlier in `priority` wins; then the score, which favours timing
// word by word and the closest length.
function rank(query, hits, priority) {
  var place = function (source) {
    var at = priority.indexOf(source);
    return at === -1 ? priority.length : at;
  };
  var scored = hits.filter(function (hit) {
    return eligible(query, hit);
  }).map(function (hit, order) {
    return {
      grade: grade(query, hit),
      place: place(hit.source),
      score: score(query, hit),
      order: order,
      hit: hit
    };
  });
  scored.sort(function (a, b) {
    return b.grade - a.grade || a.place - b.place || b.score - a.score || (a.hit.source < b.hit.source ? -1 : a.hit.source > b.hit.source ? 1 : 0) || a.order - b.order;
  });
  var seen = {};
  return scored.map(function (s) {
    return s.hit;
  }).filter(function (hit) {
    var print = fingerprint(hit);
    if (seen[print])
      return false;
    seen[print] = true;
    return true;
  });
}

// ---- words from one sheet on the lines of another ----

var LEAST = 6;
var PAIRED = 0.7;
var KEPT = 0.5;
var SEATED = 0.9;
var LIMIT = 3000;
var CELLS = 2000000;

function wide(ch) {
  var c = ch.charCodeAt(0);
  return c >= 0x3040 && (c <= 0x30ff || (c >= 0x3400 && c <= 0x4dbf) || (c >= 0x4e00 && c <= 0x9fff) || (c >= 0xac00 && c <= 0xd7af) || (c >= 0xf900 && c <= 0xfaff));
}

// A text's words as { at, key }: where each starts in the text, and its letters in lower case.
// An apostrophe is part of its word; a CJK character is a word of its own.
function tokens(text) {
  var slots = [];
  var open = null;
  for (var at = 0; at < text.length; at++) {
    var ch = text.charAt(at);
    if (wide(ch)) {
      if (open !== null)
        slots.push(open);
      open = null;
      slots.push({
        at: at,
        key: ch
      });
    } else if ("'\u2019\uff07\u2018\u00b4`".indexOf(ch) !== -1) {
      continue;
    } else if (letter(ch)) {
      if (open === null)
        open = {
          at: at,
          key: ""
        };
      open.key += ch.toLowerCase();
    } else if (open !== null) {
      slots.push(open);
      open = null;
    }
  }
  if (open !== null)
    slots.push(open);
  return slots;
}

function akin(left, right) {
  if (left === right)
    return true;
  var short = left.length <= right.length ? left : right;
  var long = left.length <= right.length ? right : left;
  return short.length >= 4 && long.length - short.length <= 2 && long.indexOf(short) === 0;
}

// The longest run of words the two share in order, as pairs of their places.
function paired(left, right) {
  var rows = left.length + 1, columns = right.length + 1;
  // Which of the right's words each of the left's is akin to, worked out once a pair.
  var table = new Uint16Array(rows * columns);
  var alike = new Uint8Array(left.length * right.length);
  for (var row = left.length - 1; row >= 0; row--) {
    var word = left[row];
    for (var column = right.length - 1; column >= 0; column--) {
      var at = row * columns + column;
      if (word === right[column] || akin(word, right[column])) {
        alike[row * right.length + column] = 1;
        table[at] = table[at + columns + 1] + 1;
      } else {
        var down = table[at + columns], across = table[at + 1];
        table[at] = down >= across ? down : across;
      }
    }
  }
  var pairs = [];
  var r = 0, c = 0;
  while (r < left.length && c < right.length) {
    if (alike[r * right.length + c] === 1) {
      pairs.push([r, c]);
      r++;
      c++;
    } else if (table[(r + 1) * columns + c] >= table[r * columns + c + 1]) {
      r++;
    } else {
      c++;
    }
  }
  return pairs;
}

// A text's words sharing out a stretch of time by their length.
function spread(text, start, end) {
  var slots = tokens(text);
  var total = 0;
  slots.forEach(function (slot) {
    total += Math.max(1, slot.key.length);
  });
  var passed = 0;
  return slots.map(function (slot) {
    var from = start + (end - start) * passed / total;
    passed += Math.max(1, slot.key.length);
    return {
      start: from,
      end: start + (end - start) * passed / total,
      key: slot.key
    };
  });
}

// Every word a sheet times, in order.
function sungWords(lines) {
  var sung = [];
  lines.forEach(function (line, index) {
    if (line.words !== null && line.words.length > 0) {
      line.words.forEach(function (word) {
        tokens(word.text).forEach(function (slot) {
          sung.push({
            start: word.start,
            end: Math.max(word.end, word.start),
            key: slot.key
          });
        });
      });
      return;
    }
    var until = line.end !== null ? line.end : index + 1 < lines.length ? lines[index + 1].start : line.start;
    sung = sung.concat(spread(line.text, line.start, Math.max(until, line.start)));
  });
  return sung;
}

// The words of `worded` (a sheet timed word by word) set on the lines of `guide` (a sheet
// timed line by line): the words keep their own times and take the guide's text and its
// division into lines. An upload timed word by word is often cut into lines by its timing
// tool rather than as the song is sung; the line-timed uploads are the ones people proofread.
// Null when the two are not the same words, in which case the worded sheet stands as it is.
function conform(worded, guide) {
  if (guide.length === 0 || worded.length === 0)
    return null;
  var sung = sungWords(worded);
  var slotted = guide.map(function (line) {
    return tokens(line.text);
  });
  var places = [];
  slotted.forEach(function (slots, line) {
    for (var s = 0; s < slots.length; s++)
      places.push([line, s]);
  });
  if (sung.length < LEAST || places.length < LEAST || sung.length > LIMIT || places.length > LIMIT || sung.length * places.length > CELLS)
    return null;
  var pairs = paired(sung.map(function (w) {
    return w.key;
  }), places.map(function (p) {
    return slotted[p[0]][p[1]].key;
  }));
  if (pairs.length < LEAST || pairs.length < PAIRED * places.length || pairs.length < KEPT * sung.length)
    return null;
  // Nearly every line of the guide has to have a word of its own to stand on.
  var held = {};
  pairs.forEach(function (pair) {
    held[places[pair[1]][0]] = true;
  });
  var counted = 0, anchored = 0;
  slotted.forEach(function (slots, line) {
    if (slots.length === 0)
      return;
    counted++;
    if (held[line])
      anchored++;
  });
  if (anchored < SEATED * counted)
    return null;

  var spans = places.map(function () {
    return null;
  });
  pairs.forEach(function (pair) {
    spans[pair[1]] = [sung[pair[0]].start, sung[pair[0]].end];
  });
  // Where the guide would put each of its words, for those the worded sheet has no time for.
  var hints = [];
  guide.forEach(function (line, index) {
    var until = line.end !== null ? line.end : index + 1 < guide.length ? guide[index + 1].start : line.start;
    spread(line.text, line.start, Math.max(until, line.start)).forEach(function (w) {
      hints.push([w.start, w.end]);
    });
  });
  var settled = [];
  var index = 0;
  while (index < spans.length) {
    if (spans[index] !== null) {
      settled.push(spans[index]);
      index++;
      continue;
    }
    var until = index;
    while (until < spans.length && spans[until] === null)
      until++;
    var after = settled.length > 0 ? settled[settled.length - 1][1] : null;
    var before = until < spans.length ? spans[until][0] : null;
    if (after !== null && before !== null && before > after) {
      // Between two words that are timed: the gap, shared out evenly.
      for (var step = 0; step < until - index; step++)
        settled.push([after + (before - after) * step / (until - index), after + (before - after) * (step + 1) / (until - index)]);
    } else {
      for (var at = index; at < until; at++) {
        var hint = hints[at] || [after !== null ? after : 0, after !== null ? after : 0];
        var start = hint[0], end = hint[1];
        if (after !== null) {
          start = Math.max(start, after);
          end = Math.max(end, start);
        }
        if (before !== null) {
          start = Math.min(start, before);
          end = Math.max(Math.min(end, before), start);
        }
        var floor = settled.length > 0 ? settled[settled.length - 1][1] : start;
        settled.push([Math.max(start, floor), Math.max(end, start, floor)]);
      }
    }
    index = until;
  }

  var lines = [];
  var cursor = 0;
  guide.forEach(function (line, li) {
    var slots = slotted[li];
    if (slots.length === 0)
      return;
    var words = slots.map(function (slot, i) {
      var from = i === 0 ? 0 : slot.at;
      var to = i + 1 < slots.length ? Math.max(slots[i + 1].at, from) : line.text.length;
      var timing = settled[cursor + i];
      return {
        start: timing[0],
        end: Math.max(timing[1], timing[0]),
        text: line.text.slice(from, to)
      };
    });
    cursor += slots.length;
    var last = 0;
    words.forEach(function (w) {
      last = Math.max(last, w.end);
    });
    lines.push({
      start: words[0].start,
      end: Math.max(last, words[0].start),
      text: line.text,
      words: words
    });
  });
  lines.sort(function (a, b) {
    return a.start - b.start;
  });
  return lines.length >= 2 ? lines : null;
}

// A hit among the ranked ones as it is shown: an upload timed word by word is set on the lines
// of the best line-timed one. A source's own sheet is left as it is.
function reshaped(hit, ranked) {
  if (!hit.worded || hit.trust >= TRUSTED)
    return hit;
  var guide = null;
  for (var i = 0; i < ranked.length && guide === null; i++)
    if (ranked[i].synced && !ranked[i].worded)
      guide = ranked[i];
  var lines = guide !== null ? conform(hit.lines, guide.lines) : null;
  if (lines === null)
    return hit;
  var out = {};
  for (var key in hit)
    out[key] = hit[key];
  out.lines = lines;
  return out;
}

// The sheet to show for the song, or null: the best of the hits, after the re-cut. `resolve`,
// where given, is asked for a hit as it will be shown before it is taken (Sheets.resolved, which
// reads an upload's word file); a hit that turns out not to time its words after all is ranked
// again as what it is. One that stops well before the song does is taken only from a source
// that is the recording's own sheet and gives the recording's length as the song's: there the
// song simply ends without words, where an upload that stops early is as likely a sheet for a
// shorter cut. (Sonora's panel puts the words up untimed in that case, which the pill cannot.)
function best(query, hits, priority, resolve) {
  var pool = hits.slice();
  for (var round = 0; round < 8; round++) {
    var ranked = rank(query, pool, priority);
    var chosen = null;
    for (var i = 0; i < ranked.length && chosen === null; i++)
      if (fullySynced(query, ranked[i]))
        chosen = ranked[i];
    if (chosen === null)
      for (var j = 0; j < ranked.length && chosen === null; j++) {
        var hit = ranked[j];
        if (hit.trust >= TRUSTED && hit.duration !== null && query.duration > 0 && Math.abs(Math.floor(hit.duration) - Math.floor(query.duration)) <= CLOSE_ENOUGH)
          chosen = hit;
      }
    if (chosen === null)
      return null;
    var shown = resolve ? resolve(chosen) : chosen;
    if (shown.worded === chosen.worded)
      return reshaped(shown, ranked);
    pool[pool.indexOf(chosen)] = shown;
  }
  return null;
}

// Of the recordings a catalogue has under the song's name, the one that is playing: those timed
// word by word first, then the nearest in length, then the one from the same album. Null when
// none of them is the song.
function pick(query, candidates) {
  var drift = function (c) {
    return c.duration !== null && query.duration > 0 ? Math.abs(Math.floor(c.duration) - Math.floor(query.duration)) : WAY_OFF;
  };
  var same = function (c) {
    return query.album && c.album && alike(c.album, query.album) ? 1 : 0;
  };
  var mine = candidates.map(function (c, order) {
    return {
      c: c,
      order: order
    };
  }).filter(function (entry) {
    return matched(query, entry.c);
  });
  mine.sort(function (a, b) {
    return (b.c.worded ? 1 : 0) - (a.c.worded ? 1 : 0) || drift(a.c) - drift(b.c) || same(b.c) - same(a.c) || a.order - b.order;
  });
  return mine.length > 0 ? mine[0].c : null;
}
