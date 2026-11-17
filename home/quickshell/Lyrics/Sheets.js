.pragma library

// Reads what each lyrics source answers into one kind of sheet, the way Sonora's own readers do
// (its crates/music/src/lyrics): Apple Music's TTML, LRCLIB's word file, and LRC. No QML
// imports: tools/lyrics-test.mjs evaluates this file under node.
//
// A sheet's lines, all times in seconds:
//   { start, end, text, words }
// `end` is null where the source gives none and nothing follows. `words` is null for a line
// timed as a whole, and otherwise its sung pieces in order, { start, end, text }: a piece is a
// word or a syllable of one, and its text ends in a space where its word ends.
//
// A hit is one sheet a source offers for a song, with what the source says the song is:
//   { source, trust, title, artist, album, duration, synced, worded, lines }
// `duration` is in seconds, or null where the source does not say. Only timed sheets are read:
// the pill has no use for words without times.

// The section labels a sheet may carry as a line of its own, such as "[Chorus]".
var SECTIONS = ["intro", "verse", "pre-chorus", "chorus", "refrain", "hook", "bridge", "breakdown", "solo", "instrumental", "outro"];

// Whether a text has a letter or a digit in it, in any script.
function alphanumeric(text) {
  if (/[0-9A-Za-z]/.test(text))
    return true;
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i);
    if (/[0-9]/.test(ch) || ch.toLowerCase() !== ch.toUpperCase())
      return true;
    if (/[\u00aa\u00ba\u02b0-\u02ff\u0370-\u1fff\u2c00-\u2dff\u3040-\u312f\u3400-\u4dbf\u4e00-\u9fff\ua000-\ud7af\uf900-\ufaff\uff10-\uff19\uff66-\uffdc]/.test(ch))
      return true;
  }
  return false;
}

// A line that is not sung: nothing but marks, or a section's name in brackets or dashes.
function structural(text) {
  var t = String(text).trim();
  if (t === "" || !alphanumeric(t))
    return true;
  var wrapped = (t.charAt(0) === "[" && t.charAt(t.length - 1) === "]") || (t.charAt(0) === "-" && t.charAt(t.length - 1) === "-");
  if (!wrapped)
    return false;
  var label = t.replace(/^[\s\[\]\-\u2014]+|[\s\[\]\-\u2014]+$/g, "").toLowerCase();
  return SECTIONS.indexOf(label) !== -1;
}

// Puts a sheet's lines in order, ends each where the next begins when it has no end of its own,
// and drops what is not sung.
function normalize(lines) {
  lines.sort(function (a, b) {
    return a.start - b.start;
  });
  for (var i = 0; i + 1 < lines.length; i++)
    if (lines[i].end === null)
      lines[i].end = lines[i + 1].start;
  lines.forEach(function (line) {
    if (line.end === null || !line.words || line.words.length === 0)
      return;
    var last = line.words[line.words.length - 1];
    if (last.end <= last.start)
      last.end = Math.max(line.end, last.start);
  });
  return lines.filter(function (line) {
    line.text = String(line.text).replace(/\s+/g, " ").trim();
    return !structural(line.text);
  });
}

function worded(lines) {
  return lines.some(function (line) {
    return line.words !== null && line.words.length > 0;
  });
}

// ---- TTML: Apple Music's sheets ----

function entities(text) {
  return String(text).replace(/&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);/g, function (whole, name) {
    if (name === "amp")
      return "&";
    if (name === "lt")
      return "<";
    if (name === "gt")
      return ">";
    if (name === "quot")
      return "\"";
    if (name === "apos")
      return "'";
    var code = name.charAt(1) === "x" ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
    return isFinite(code) && code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : whole;
  });
}

// A small reader for well-formed XML: elements as { name, attrs, children }, text as strings.
// Names lose their prefix ("ttm:role" is "role"), which is all a TTML sheet needs told apart.
function xml(text) {
  var root = {
    name: "",
    attrs: {},
    children: []
  };
  var open = [root];
  var token = /<!--[\s\S]*?-->|<\?[\s\S]*?\?>|<!\[CDATA\[([\s\S]*?)\]\]>|<!DOCTYPE[^>]*>|<(\/?)([^\s\/>]+)([^>]*?)(\/?)>|([^<]+)/g;
  var local = function (name) {
    var colon = name.indexOf(":");
    return colon === -1 ? name : name.slice(colon + 1);
  };
  var m;
  while ((m = token.exec(String(text))) !== null) {
    var top = open[open.length - 1];
    if (m[1] !== undefined) {
      top.children.push(m[1]);
    } else if (m[6] !== undefined) {
      top.children.push(entities(m[6]));
    } else if (m[3] !== undefined) {
      if (m[2] === "/") {
        if (open.length > 1)
          open.pop();
        continue;
      }
      var node = {
        name: local(m[3]),
        attrs: {},
        children: []
      };
      var attr = /([^\s=]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g;
      var a;
      while ((a = attr.exec(m[4])) !== null)
        node.attrs[local(a[1])] = entities(a[2] !== undefined ? a[2] : a[3]);
      top.children.push(node);
      if (m[5] !== "/")
        open.push(node);
    }
  }
  return root;
}

function descendants(node, name, out) {
  node.children.forEach(function (child) {
    if (typeof child === "string")
      return;
    if (child.name === name)
      out.push(child);
    descendants(child, name, out);
  });
  return out;
}

// "9.497", "1:02.5", "0:01:02.500" or "62.5s", as seconds; null when it is none of them.
function ttmlStamp(text) {
  if (text === undefined || text === null)
    return null;
  var parts = String(text).trim().replace(/s$/, "").split(":");
  var seconds = 0;
  for (var i = 0; i < parts.length; i++) {
    if (!/^\d+(\.\d+)?$/.test(parts[i]))
      return null;
    seconds = seconds * 60 + Number(parts[i]);
  }
  return isFinite(seconds) ? Math.max(0, seconds) : null;
}

// What is sung with the line but is not the line: backing voices, a translation, a romanisation.
function aside(node) {
  var role = node.attrs.role;
  return role === "x-bg" || role === "x-translation" || role === "x-roman";
}

// The timed pieces under a paragraph. Text between two of them (the space between words) joins
// the piece before it, which is how a word's end is told from a syllable's. Backing voices are
// gathered apart, into `backing`, each as the pieces of its own stretch.
function ttmlSung(parent, out, backing) {
  parent.children.forEach(function (child) {
    if (typeof child === "string") {
      if (out.length > 0)
        out[out.length - 1].text += child;
      return;
    }
    if (aside(child)) {
      if (child.attrs.role === "x-bg" && backing) {
        var behind = ttmlSung(child, [], null);
        if (behind.length > 0)
          backing.push(behind);
      }
      return;
    }
    if (child.attrs.begin === undefined) {
      ttmlSung(child, out, backing);
      return;
    }
    var start = ttmlStamp(child.attrs.begin);
    if (start === null)
      return;
    var end = ttmlStamp(child.attrs.end);
    var text = child.children.filter(function (c) {
      return typeof c === "string";
    }).join("");
    if (text.trim() !== "")
      out.push({
        start: start,
        end: Math.max(end === null ? start : end, start),
        text: text
      });
  });
  return out;
}

function ttmlSpoken(node) {
  var text = "";
  (function walk(n) {
    n.children.forEach(function (child) {
      if (typeof child === "string")
        text += child;
      else if (!aside(child))
        walk(child);
    });
  })(node);
  return text.replace(/\s+/g, " ").trim();
}

// A stretch of backing voices as a line of its own, in brackets as a sheet writes them.
function backingLine(pieces) {
  var words = pieces.map(function (w) {
    return {
      start: w.start,
      end: w.end,
      text: w.text
    };
  });
  var said = words.map(function (w) {
    return w.text;
  }).join("").trim();
  if (said.indexOf("(") === -1 && said.indexOf(")") === -1) {
    words[0].text = "(" + words[0].text;
    words[words.length - 1].text = words[words.length - 1].text.replace(/\s+$/, "") + ")";
    said = "(" + said + ")";
  }
  return {
    start: words[0].start,
    end: Math.max(words[words.length - 1].end, words[0].start),
    text: said,
    words: words
  };
}

// A TTML sheet's lines, or [] when it has none that are timed. Backing voices sung once the
// line's own words are over, or before they begin, are lines of their own; those sung under the
// line are left out, the pill having one line to show.
function fromTtml(text) {
  var lines = [];
  descendants(xml(text), "p", []).forEach(function (p) {
    var backing = [];
    var words = ttmlSung(p, [], backing);
    var said = words.length > 0 ? words.map(function (w) {
      return w.text;
    }).join("").trim() : ttmlSpoken(p);
    var begin = ttmlStamp(p.attrs.begin);
    var end = ttmlStamp(p.attrs.end);
    var first = words.length > 0 ? words[0].start : begin;
    var last = words.length > 0 ? words[words.length - 1].end : end;
    var behind = backing.map(backingLine).filter(function (b) {
      return said === "" || first === null || last === null || b.start >= last - 0.05 || b.end <= first + 0.05;
    });
    if (said !== "") {
      var start = begin !== null ? begin : words.length > 0 ? words[0].start : 0;
      // The line is over when its own words are, not when the voices behind it are.
      var until = words.length > 0 ? words[words.length - 1].end : end;
      lines.push({
        start: start,
        end: until === null ? null : Math.max(until, start),
        text: said,
        words: words.length > 0 ? words : null
      });
    }
    lines = lines.concat(behind);
  });
  var timed = lines.some(function (line) {
    return line.end !== null || line.words !== null;
  });
  return timed ? normalize(lines) : [];
}

// ---- LRC ----

// "mm:ss.xx", "hh:mm:ss.xx" or "mm:ss:xx" (a comma for the point is taken too), as seconds.
function lrcStamp(text) {
  var parts = String(text).trim().replace(",", ".").split(":");
  if (parts.length < 2 || parts.length > 3)
    return null;
  var whole = function (s) {
    return /^\d+$/.test(s) ? Number(s) : null;
  };
  var real = function (s) {
    return /^\d+(\.\d+)?$/.test(s) ? Number(s) : null;
  };
  var seconds;
  if (parts.length === 2) {
    var m = whole(parts[0]), s = real(parts[1]);
    if (m === null || s === null)
      return null;
    seconds = m * 60 + s;
  } else if (parts[2].indexOf(".") !== -1) {
    var h = whole(parts[0]), mm = whole(parts[1]), ss = real(parts[2]);
    if (h === null || mm === null || ss === null)
      return null;
    seconds = h * 3600 + mm * 60 + ss;
  } else {
    var min = whole(parts[0]), sec = whole(parts[1]);
    if (min === null || sec === null || whole(parts[2]) === null)
      return null;
    seconds = min * 60 + sec + Number("0." + parts[2]);
  }
  return isFinite(seconds) ? seconds : null;
}

// A line's words where it carries "<mm:ss.xx>" marks between them, and its text without them.
function lrcSpoken(body) {
  var segments = [{
      at: null,
      text: ""
    }];
  var rest = body;
  for (; ; ) {
    var open = rest.indexOf("<");
    if (open === -1)
      break;
    var shut = rest.indexOf(">", open + 1);
    if (shut === -1)
      break;
    var at = lrcStamp(rest.slice(open + 1, shut));
    var last = segments[segments.length - 1];
    if (at !== null) {
      last.text += rest.slice(0, open);
      segments.push({
        at: at,
        text: ""
      });
    } else {
      last.text += rest.slice(0, shut + 1);
    }
    rest = rest.slice(shut + 1);
  }
  segments[segments.length - 1].text += rest;
  var whole = segments.map(function (s) {
    return s.text;
  }).join("");
  var timed = segments.filter(function (s) {
    return s.at !== null;
  });
  if (timed.length === 0)
    return {
      text: whole.trim(),
      words: null
    };
  var words = [];
  timed.forEach(function (segment, i) {
    if (segment.text === "") {
      // A mark with nothing after it is where the word before it ends.
      if (words.length > 0)
        words[words.length - 1].end = Math.max(segment.at, words[words.length - 1].start);
      return;
    }
    var next = i + 1 < timed.length ? timed[i + 1].at : null;
    words.push({
      start: segment.at,
      end: next !== null && next > segment.at ? next : segment.at,
      text: segment.text
    });
  });
  return {
    text: whole.replace(/\s+$/, ""),
    words: words.length > 0 ? words : null
  };
}

function lrcRead(raw) {
  var rest = raw.trim();
  var stamps = [];
  for (; ; ) {
    var m = /^\[([^\]]*)\]/.exec(rest);
    if (!m)
      break;
    var at = lrcStamp(m[1]);
    if (at === null)
      break;
    stamps.push(at);
    rest = rest.slice(m[0].length).replace(/^\s+/, "");
  }
  if (stamps.length === 0)
    return [];
  // "[start] words [end]": a stamp closing the line is where it ends.
  var closed = null;
  var tail = /^([\s\S]*\S)\s*\[([^\[\]]*)\]\s*$/.exec(rest);
  if (tail && lrcStamp(tail[2]) !== null) {
    closed = lrcStamp(tail[2]);
    rest = tail[1];
  }
  var spoken = lrcSpoken(rest);
  return stamps.map(function (start) {
    var words = spoken.words;
    if (words !== null && words.length > 0) {
      // A line stamped more than once is sung again each time: its words move with the stamp.
      var drift = start - words[0].start;
      words = words.map(function (w) {
        return {
          start: w.start + (drift > 0 ? drift : 0),
          end: w.end + (drift > 0 ? drift : 0),
          text: w.text
        };
      });
    }
    return {
      start: start,
      end: closed !== null && closed > start ? closed : null,
      text: spoken.text,
      words: words
    };
  });
}

// An LRC text's lines: "[mm:ss.xx] words", with "<mm:ss.xx>" between words where it times them,
// and an "[offset:ms]" tag moving the whole sheet.
function fromLrc(text) {
  var shift = 0;
  var lines = [];
  String(text).split(/\r?\n/).forEach(function (raw) {
    var offset = /^\s*\[\s*offset\s*:\s*([+-]?\d+)\s*\]\s*$/i.exec(raw);
    if (offset) {
      shift += Number(offset[1]);
      return;
    }
    lines = lines.concat(lrcRead(raw));
  });
  if (shift !== 0) {
    var by = -shift / 1000;
    var moved = function (at) {
      return Math.max(0, at + by);
    };
    lines.forEach(function (line) {
      line.start = moved(line.start);
      if (line.end !== null)
        line.end = moved(line.end);
      if (line.words !== null)
        line.words.forEach(function (w) {
          w.start = moved(w.start);
          w.end = moved(w.end);
        });
    });
  }
  return normalize(lines);
}

// ---- LRCLIB's word file ----

// One YAML scalar as its value: plain, 'single quoted' or "double quoted".
function yamlScalar(raw) {
  var v = raw.trim();
  if (v.length >= 2 && v.charAt(0) === "'" && v.charAt(v.length - 1) === "'")
    return v.slice(1, -1).replace(/''/g, "'");
  if (v.length >= 2 && v.charAt(0) === "\"" && v.charAt(v.length - 1) === "\"") {
    try {
      return String(JSON.parse(v));
    } catch (e) {
      return v.slice(1, -1);
    }
  }
  return v;
}

// A quoted scalar that its line does not close runs on to the next.
function yamlOpen(raw) {
  var v = raw.trim();
  if (v.charAt(0) === "'")
    return (v.replace(/''/g, "").match(/'/g) || []).length < 2;
  if (v.charAt(0) === "\"")
    return (v.replace(/\\./g, "").match(/"/g) || []).length < 2;
  return false;
}

// The lines of a LRCLIB "lyricsfile": a YAML document whose `lines` each have `text`,
// `start_ms`, perhaps `end_ms`, and perhaps `words` with the same three. It is read as the
// shape it is rather than as YAML at large; null when that shape is not there, so the upload's
// LRC is read instead.
function fromLyricsFile(text) {
  var rows = String(text).split(/\r?\n/);
  var at = 0;
  while (at < rows.length && !/^lines:\s*$/.test(rows[at]))
    at++;
  if (at >= rows.length)
    return null;
  var lines = [];
  var line = null, word = null, target = null, inWords = false, base = -1;
  var folding = null, foldFrom = 0;
  for (at++; at < rows.length; at++) {
    var row = rows[at];
    if (row.trim() === "")
      continue;
    var indent = row.length - row.replace(/^ +/, "").length;
    // Back at the margin with another key: the list is over.
    if (indent === 0 && !/^- /.test(row))
      break;
    var m = /^( *)(- +)?([a-z_]+):(?: (.*)|)$/.exec(row);
    if (!m) {
      // A long text folded onto a second line: inside its quotes, or plain and set in further.
      if (target !== null && target.pending !== undefined) {
        target.pending += " " + row.trim();
        if (!yamlOpen(target.pending)) {
          target.text = yamlScalar(target.pending);
          delete target.pending;
        }
        continue;
      }
      if (folding !== null && indent > foldFrom) {
        folding.text += " " + row.trim();
        continue;
      }
      return null;
    }
    folding = null;
    var dash = m[2] !== undefined;
    var key = m[3];
    var value = m[4] === undefined ? "" : m[4];
    if (dash) {
      if (base === -1)
        base = indent;
      if (indent <= base) {
        line = {
          text: "",
          start: null,
          end: null,
          words: []
        };
        lines.push(line);
        word = null;
        inWords = false;
        target = line;
      } else if (line !== null && inWords) {
        word = {
          text: "",
          start: null,
          end: null
        };
        line.words.push(word);
        target = word;
      } else {
        return null;
      }
    } else if (line === null) {
      return null;
    } else if (word !== null && indent <= base + 2) {
      // A key of the line again, after its words.
      word = null;
      inWords = false;
      target = line;
    }
    if (key === "words") {
      inWords = true;
      word = null;
      target = line;
    } else if (key === "text") {
      if (yamlOpen(value)) {
        target.pending = value;
      } else {
        target.text = yamlScalar(value);
        if (!/^['"]/.test(value.trim())) {
          folding = target;
          foldFrom = indent + (dash ? m[2].length : 0);
        }
      }
    } else if (key === "start_ms" || key === "end_ms") {
      var ms = Number(yamlScalar(value));
      if (isFinite(ms) && value.trim() !== "" && value.trim() !== "null" && value.trim() !== "~")
        target[key === "start_ms" ? "start" : "end"] = ms / 1000;
    }
  }
  var out = [];
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i];
    if (l.start === null || l.pending !== undefined)
      return null;
    var words = [];
    for (var j = 0; j < l.words.length; j++) {
      var w = l.words[j];
      if (w.start === null || w.pending !== undefined)
        return null;
      words.push({
        start: w.start,
        end: w.end !== null ? w.end : w.start,
        text: w.text
      });
    }
    out.push({
      start: l.start,
      end: l.end,
      text: l.text,
      words: words.length > 0 ? words : null
    });
  }
  out = normalize(out);
  return out.length > 0 ? out : null;
}

// ---- what each source answers ----

function hit(source, trust, lines, title, artist, album, duration) {
  return {
    source: source,
    trust: trust,
    title: String(title || ""),
    artist: String(artist || ""),
    album: album ? String(album) : "",
    duration: typeof duration === "number" && isFinite(duration) && duration > 0 ? duration : null,
    synced: true,
    worded: worded(lines),
    lines: lines
  };
}

// LRCLIB's search: every upload it has for the song, as hits. An upload has an LRC, timed by
// line, and may have a word file timing its words too. Reading a word file is ten times the
// work of an LRC and a song has twenty uploads, so where the upload says its file times the
// words the hit is made from the LRC, said to be `worded`, and carries the file unread as
// `file`: `resolved` reads it for the one hit that is shown. An upload with plain words only
// is no use here. `wanted`, where given, is asked of each upload's own account of itself before
// its sheet is read, so the sheets of other songs and other recordings are not read at all.
function lrclibHits(text, wanted) {
  var found;
  try {
    found = JSON.parse(text);
  } catch (e) {
    return null;
  }
  if (!Array.isArray(found))
    return null;
  var hits = [];
  found.forEach(function (row) {
    if (!row)
      return;
    var about = hit("LRCLIB", 0, [], row.trackName, row.artistName, row.albumName === "null" ? "" : row.albumName, Number(row.duration));
    if (wanted && !wanted(about))
      return;
    var file = typeof row.lyricsfile === "string" ? row.lyricsfile : null;
    var lines = typeof row.syncedLyrics === "string" ? fromLrc(row.syncedLyrics) : [];
    if (file !== null && row.hasWordSync === true && lines.length > 0) {
      about.lines = lines;
      about.worded = true;
      about.file = file;
    } else {
      // No word that the file is worth the reading, or no LRC to stand in for it: read now.
      var filed = file !== null && row.hasWordSync !== false ? fromLyricsFile(file) : null;
      if (filed === null && lines.length === 0 && file !== null)
        filed = fromLyricsFile(file);
      about.lines = filed !== null ? filed : lines;
      about.worded = worded(about.lines);
    }
    if (about.lines.length > 0)
      hits.push(about);
  });
  return hits;
}

// A hit with its word file read (see lrclibHits): its lines are the file's. A file that cannot
// be read leaves the hit as its LRC has it, timed by line.
function resolved(found) {
  if (typeof found.file !== "string")
    return found;
  var out = {};
  for (var key in found)
    if (key !== "file")
      out[key] = found[key];
  var filed = fromLyricsFile(found.file);
  if (filed !== null)
    out.lines = filed;
  out.worded = worded(out.lines);
  return out;
}

// The Apple Music catalogue's search: the recordings it knows, each with where its sheet is.
// Those timed word by word come first, as Sonora takes them.
function appleMatches(text) {
  var found;
  try {
    found = JSON.parse(text);
  } catch (e) {
    return null;
  }
  if (!found || !Array.isArray(found.results))
    return null;
  var matches = [];
  found.results.forEach(function (row) {
    if (!row || typeof row.lyricsUrl !== "string" || row.lyricsUrl.indexOf("https://") !== 0)
      return;
    matches.push({
      title: String(row.track_name || ""),
      artist: String(row.artist_name || ""),
      album: String(row.album_name || ""),
      duration: Number(row.duration) > 0 ? Number(row.duration) : null,
      worded: row.timing_type === "word" || row.timing_type === "syllable",
      url: row.lyricsUrl
    });
  });
  var first = matches.filter(function (m) {
    return m.worded;
  });
  return first.concat(matches.filter(function (m) {
    return !m.worded;
  }));
}

// The sheet of one of those recordings, as a hit; null when it has no timed lines.
function appleHit(match, ttml) {
  var lines = fromTtml(ttml);
  return lines.length > 0 ? hit("Apple Music", 180, lines, match.title, match.artist, match.album, match.duration) : null;
}
