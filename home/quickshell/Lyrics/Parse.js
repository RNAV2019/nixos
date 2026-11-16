.pragma library

// Turns what a lyrics service answers into the one shape lyrics are drawn from. No QML
// imports: tools/lyrics-test.mjs evaluates this file under node.
//
// The shape, all times in seconds:
//   { source, wordTimed, lines: [line], parts: [part] }
//   line: { t, end, out, text, part, words: [{ t, d, text }] }
//   part: { name, tier, firstLine, lastLine }
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

function cleanArtist(artist) {
  var a = String(artist || "");
  a = a.replace(/\s+-\s+topic$/i, "").replace(/vevo$/i, "");
  // The first name is the one a lyrics service files the song under.
  a = a.split(/\s*(?:,|;|\sfeat\.?\s|\sft\.?\s|\s&\s|\sx\s)\s*/i)[0];
  return a.replace(/\s+/g, " ").trim();
}

// A browser tab playing a video reports the whole of "Artist - Title" as its title.
function splitTitle(title, artist) {
  var t = String(title || "");
  var m = /^(.+?)\s+[-–—]\s+(.+)$/.exec(t);
  if (m && (!artist || /topic$|vevo$/i.test(artist) || t.toLowerCase().indexOf(String(artist).toLowerCase()) === 0))
    return {
      title: cleanTitle(m[2]),
      artist: cleanArtist(m[1])
    };
  return {
    title: cleanTitle(t),
    artist: cleanArtist(artist)
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

// "Verse", "Pre-Chorus", "Chorus"... as how hard that part of the song hits.
function tierOf(name) {
  var n = String(name || "").toLowerCase().replace(/[^a-z]/g, "");
  if (n.indexOf("pre") === 0)
    return "mid";
  if (/chorus|hook|refrain|drop/.test(n))
    return "high";
  if (/bridge|intro|outro|interlude|break/.test(n))
    return "calm";
  return "mid";
}

// Fills in `end` and `out`, drops what cannot be drawn, and makes sure every line has a part.
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
  model.parts = partsOf(model);
  return lines.length > 0 ? model : null;
}

// The song's parts as runs of lines. A source that names none gets them guessed: a pause opens a
// new part, and lines sung three times or more are taken for the chorus.
function partsOf(model) {
  var lines = model.lines;
  var named = model.parts && model.parts.length > 0;
  var parts = [];
  if (named) {
    for (var i = 0; i < lines.length; i++) {
      var p = model.parts[lines[i].part];
      var name = p ? p.name : "Verse";
      var open = parts.length > 0 ? parts[parts.length - 1] : null;
      if (open && open.source === lines[i].part) {
        open.lastLine = i;
      } else {
        parts.push({
          name: name,
          tier: tierOf(name),
          source: lines[i].part,
          firstLine: i,
          lastLine: i
        });
      }
      lines[i].part = parts.length - 1;
    }
    return parts;
  }
  var seen = {};
  var key = function (l) {
    return l.text.toLowerCase().replace(/[^a-z0-9 ]/g, "");
  };
  lines.forEach(function (l) {
    seen[key(l)] = (seen[key(l)] || 0) + 1;
  });
  for (var j = 0; j < lines.length; j++) {
    var chorus = seen[key(lines[j])] >= 3;
    var cur = parts.length > 0 ? parts[parts.length - 1] : null;
    var gap = j > 0 ? lines[j].t - lines[j - 1].end : 0;
    if (!cur || gap > 4 || (cur.tier === "high") !== chorus) {
      parts.push({
        name: chorus ? "Chorus" : "Verse",
        tier: chorus ? "high" : "mid",
        firstLine: j,
        lastLine: j
      });
    } else {
      cur.lastLine = j;
    }
    lines[j].part = parts.length - 1;
  }
  return parts;
}

// LyricsPlus (v2): times in milliseconds, a line's `syllabus` holding its syllables, a
// syllable ending in a space where its word ends.
function fromLyricsPlus(text) {
  var data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    return null;
  }
  if (!data || !Array.isArray(data.lyrics) || data.lyrics.length === 0)
    return null;
  var wordTimed = data.type === "Word";
  var lines = data.lyrics.map(function (row, i) {
    var t = Number(row.time) / 1000;
    var d = Number(row.duration) / 1000;
    var words = [];
    var syl = Array.isArray(row.syllabus) ? row.syllabus : [];
    if (wordTimed && syl.length > 1) {
      var open = null;
      syl.forEach(function (s) {
        var raw = String(s.text || "");
        if (raw.trim() === "")
          return;
        var st = Number(s.time) / 1000;
        var sd = Math.max(0.04, Number(s.duration) / 1000);
        if (open === null) {
          open = {
            t: st,
            d: sd,
            text: raw.trim()
          };
        } else {
          open.text += raw.trim();
          open.d = st + sd - open.t;
        }
        if (/\s$/.test(raw)) {
          words.push(open);
          open = null;
        }
      });
      if (open !== null)
        words.push(open);
    } else {
      var next = i + 1 < data.lyrics.length ? Number(data.lyrics[i + 1].time) / 1000 : t + 6;
      words = spreadWords(row.text, t, d > 0.2 ? d : Math.max(0.5, next - t));
    }
    return {
      t: words.length > 0 ? words[0].t : t,
      words: words,
      part: row.element && typeof row.element.songPartIndex === "number" ? row.element.songPartIndex : 0
    };
  });
  var meta = data.metadata || {};
  return finish({
    source: String(meta.source || "LyricsPlus"),
    wordTimed: wordTimed,
    lines: lines,
    parts: Array.isArray(meta.songParts) ? meta.songParts.map(function (p) {
      return {
        name: String(p.name || "Verse")
      };
    }) : []
  });
}

// LRCLIB: `syncedLyrics` is LRC text, one "[mm:ss.xx] words" per line and nothing finer.
function fromLrclib(text) {
  var data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    return null;
  }
  if (!data || typeof data.syncedLyrics !== "string" || data.syncedLyrics.trim() === "")
    return null;
  var rows = [];
  data.syncedLyrics.split("\n").forEach(function (raw) {
    var m = /^\s*\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/.exec(raw);
    if (m)
      rows.push({
        t: Number(m[1]) * 60 + Number(m[2]),
        text: m[3].trim()
      });
  });
  var lines = [];
  rows.forEach(function (row, i) {
    if (row.text === "")
      return;
    var next = i + 1 < rows.length ? rows[i + 1].t : row.t + 5;
    lines.push({
      t: row.t,
      words: spreadWords(row.text, row.t, Math.max(0.4, next - row.t - 0.15)),
      part: 0
    });
  });
  return finish({
    source: "LRCLIB",
    wordTimed: false,
    lines: lines,
    parts: []
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
