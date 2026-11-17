.pragma library

// Names as players give them, and a sheet of lyrics (Sheets.js) as the one shape the pill is
// drawn from. No QML imports: tools/lyrics-test.mjs evaluates this file under node.
//
// The shape, all times in seconds:
//   { source, wordTimed, lines: [line] }
//   line: { t, end, out, text, index, words: [{ t, d, text }] }
// `end` is where the last word stops; `out` is when the line should leave the screen, which is
// the next line's start when that follows closely and a short hold after `end` otherwise.

// How long a line may stay up once it has been sung, with nothing following it.
var HOLD = 1.4;
// A next line that starts within this of the line's end takes its place directly.
var CLOSE = 3.0;
// A sung syllable, when a line's own length says nothing better.
var SYLLABLE = 0.24;

// What a player calls the track, without what a video site adds to it.
function cleanTitle(title) {
  var t = String(title || "");
  t = t.replace(/\s*[\(\[][^\)\]]*(official|video|audio|lyric|visuali[sz]er|remaster|explicit|clean|hd|4k|mv|live at|live from)[^\)\]]*[\)\]]/gi, "");
  t = t.replace(/\s*[\(\[]\s*(feat|ft|with)\.?\s[^\)\]]*[\)\]]/gi, "");
  t = t.replace(/\s+-\s+(\d{4}\s+)?(remaster(ed)?|single version|radio edit|mono|stereo)(\s+\d{4})?.*$/i, "");
  return t.replace(/\s+/g, " ").trim();
}

// Who a player says the song is by, without what a video site adds: every name it gives.
function cleanArtists(artist) {
  return String(artist || "").replace(/\s+-\s+topic$/i, "").replace(/vevo$/i, "").replace(/\s+/g, " ").trim();
}

// The first of them: the name the pill shows beside the title.
function cleanArtist(artist) {
  return cleanArtists(artist).split(/\s*(?:,|;|\sfeat\.?\s|\sft\.?\s|\s&\s|\sx\s)\s*/i)[0].trim();
}

// A browser tab playing a video reports the whole of "Artist - Title" as its title.
function splitTitle(title, artist) {
  var t = String(title || "");
  var m = /^(.+?)\s+[-–—]\s+(.+)$/.exec(t);
  if (m && (!artist || /topic$|vevo$/i.test(artist) || t.toLowerCase().indexOf(String(artist).toLowerCase()) === 0))
    return {
      title: cleanTitle(m[2]),
      artist: cleanArtist(m[1]),
      artists: cleanArtists(m[1])
    };
  return {
    title: cleanTitle(t),
    artist: cleanArtist(artist),
    artists: cleanArtists(artist)
  };
}

// Roughly how many syllables a word is sung as: its runs of vowels.
function syllables(word) {
  var groups = String(word).toLowerCase().replace(/[^a-zà-ÿ]/g, "").match(/[aeiouyà-ÿ]+/g);
  var n = groups ? groups.length : 1;
  if (n > 1 && /[^aeiouy]e$/.test(String(word).toLowerCase().replace(/[^a-z]/g, "")))
    n -= 1;
  return Math.max(1, n);
}

// Words for a line that came with a start and nothing finer: its length shared out by syllables.
function spreadWords(text, t, room) {
  var parts = String(text).trim().split(/\s+/).filter(function (w) {
    return w !== "";
  });
  var total = 0;
  var weights = parts.map(function (w) {
    var s = syllables(w);
    total += s;
    return s;
  });
  if (parts.length === 0)
    return [];
  var span = Math.max(0.3, Math.min(room, total * SYLLABLE * 1.6));
  var at = t;
  return parts.map(function (w, i) {
    var d = span * weights[i] / total;
    var word = {
      t: at,
      d: d,
      text: w
    };
    at += d;
    return word;
  });
}

// Fills in `end` and `out`, and drops what cannot be drawn.
function finish(model) {
  var lines = model.lines.filter(function (l) {
    return l.words.length > 0;
  });
  lines.sort(function (a, b) {
    return a.t - b.t;
  });
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i];
    var last = l.words[l.words.length - 1];
    l.end = Math.max(l.t + 0.2, last.t + last.d);
    var next = i + 1 < lines.length ? lines[i + 1].t : Infinity;
    // Words never run into the next line: a held last word gives way to it.
    if (l.end > next && next > last.t + 0.1) {
      last.d = next - last.t;
      l.end = next;
    }
    l.out = next - l.end < CLOSE ? Math.max(next, l.t + 0.2) : l.end + HOLD;
    l.text = l.words.map(function (w) {
      return w.text;
    }).join(" ");
    l.index = i;
  }
  model.lines = lines;
  return lines.length > 0 ? model : null;
}

// A sheet's sung pieces (Sheets.js: words, or syllables of them) as the words the pill draws. A
// piece whose text ends in a space ends its word; one without an end of its own lasts until
// the next begins.
function wordsOf(line) {
  var pieces = line.words;
  var out = [];
  var open = null;
  var shut = function () {
    if (open !== null)
      out.push(open);
    open = null;
  };
  for (var i = 0; i < pieces.length; i++) {
    var raw = String(pieces[i].text);
    var start = pieces[i].start;
    var end = pieces[i].end;
    if (!(end > start))
      end = i + 1 < pieces.length ? pieces[i + 1].start : line.end !== null ? line.end : start;
    end = Math.max(end, start + 0.04);
    if (/^\s/.test(raw))
      shut();
    var said = raw.trim().split(/\s+/).filter(function (w) {
      return w !== "";
    });
    var letters = said.join("").length;
    var passed = 0;
    for (var k = 0; k < said.length; k++) {
      // Two words under one time share it by their length.
      var from = start + (end - start) * passed / letters;
      passed += said[k].length;
      var to = start + (end - start) * passed / letters;
      if (k > 0)
        shut();
      if (open === null) {
        open = {
          t: from,
          d: to - from,
          text: said[k]
        };
      } else {
        open.text += said[k];
        open.d = to - open.t;
      }
    }
    if (/\s$/.test(raw))
      shut();
  }
  shut();
  return out;
}

// One of the sheets a source offered (Sheets.js's hit) as what the pill is drawn from. A line
// timed as a whole has its length shared out among its words.
function fromSheet(hit) {
  var lines = hit.lines.map(function (line, i) {
    var words;
    if (line.words !== null && line.words.length > 0) {
      words = wordsOf(line);
    } else {
      var until = line.end !== null ? line.end : i + 1 < hit.lines.length ? hit.lines[i + 1].start : line.start + 5;
      words = spreadWords(line.text, line.start, Math.max(0.4, until - line.start - 0.15));
    }
    return {
      t: words.length > 0 ? words[0].t : line.start,
      words: words
    };
  });
  return finish({
    source: hit.source,
    wordTimed: hit.worded,
    lines: lines
  });
}

// A file name for a track's cached lyrics: what identifies the song, and nothing a path minds.
function cacheKey(title, artist, seconds) {
  var s = (String(artist) + "-" + String(title)).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 96);
  return (s || "untitled") + "-" + Math.round(Number(seconds) || 0);
}

// The index of the line that is up at `now`: the last that has started (`lead` early), or -1.
function lineAt(lines, now, lead) {
  var lo = 0, hi = lines.length - 1, found = -1;
  while (lo <= hi) {
    var mid = (lo + hi) >> 1;
    if (lines[mid].t - lead <= now) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return found;
}
