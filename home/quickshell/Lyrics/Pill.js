.pragma library

// The lyric pill's plain logic: how a song's lines are cut to what the pill can hold, when each
// comes up and goes, and what a word looks like at a moment of the song. Everything is a function
// of the song's time, so the pill at 38.2 s is the same picture every run. No QML imports:
// tools/lyrics-test.mjs evaluates this file under node.
//
// A phrase is a line, or a stretch of one too long for the pill:
//   { line, t, end, out, text, width, words: [{ t, d, text }], start, stop, fromRest, toRest }
// `start` is when it comes up and `stop` when it starts to leave; `fromRest` and `toRest` say
// whether the plain pill is what stands before and after it.

// A phrase is up this long before its first word, so it is in place when the voice is.
var LEAD = 0.25;
// From the plain pill, the shape starts to widen this much sooner still, and after a phrase that
// nothing follows it stays wide this long: the clock goes before the words come, and the words
// are gone before it is back.
var EARLY = 0.16;
var LATE = 0.14;
// A word's way in, the wait between one word's and the next's, and a phrase's way out. A
// phrase that takes another's place waits FOLLOW for it to start on its way first.
var ARRIVE = 0.36;
var STAGGER = 0.03;
var LEAVE = 0.2;
var FOLLOW = 0.05;
// The word being sung rises over this long (half its own length, if that is shorter), comes
// back down over FALL once sung, and eases to a sung word's ink over SETTLE.
var RISE = 0.18;
var FALL = 0.42;
var SETTLE = 0.7;
// How many letters wide the soft front of the fill is.
var SOFT = 2.2;
// A word held this long is as heavy as a word gets; one shorter than HELD_FROM has no weight.
var HELD_FROM = 0.45;
var HELD_FULL = 1.55;

function clamp01(x) {
  return x < 0 ? 0 : x > 1 ? 1 : x;
}

function smooth(x) {
  x = clamp01(x);
  return x * x * (3 - 2 * x);
}

function outCubic(x) {
  x = clamp01(x);
  return 1 - (1 - x) * (1 - x) * (1 - x);
}

// Where to cut a line of words `widths` wide (px each, `space` between) so no stretch is wider
// than `max`: the fewest stretches that fit, as even as they can be, a cut after a comma or a
// full stop preferred. A word wider than the pill on its own is a stretch by itself. Answers
// [[from, to)...].
function cuts(texts, widths, space, max) {
  var n = widths.length;
  if (n === 0)
    return [];
  function span(a, b) {
    var w = 0;
    for (var i = a; i < b; i++)
      w += widths[i] + (i > a ? space : 0);
    return w;
  }
  if (span(0, n) <= max)
    return [[0, n]];
  // best[k][i]: the least cost of the first i words in k stretches, and where the last begins.
  for (var groups = 2; groups <= n; groups++) {
    var best = [];
    for (var k = 0; k <= groups; k++) {
      best.push([]);
      for (var i = 0; i <= n; i++)
        best[k].push({
          cost: Infinity,
          from: -1
        });
    }
    best[0][0].cost = 0;
    for (k = 1; k <= groups; k++) {
      for (i = k; i <= n; i++) {
        for (var j = k - 1; j < i; j++) {
          if (best[k - 1][j].cost === Infinity)
            continue;
          var w = span(j, i);
          if (w > max && i - j > 1)
            continue;
          // A cut the song already makes (after punctuation) costs less than one it does not.
          var eased = j > 0 && /[,;:.!?…—–-]$/.test(texts[j - 1]) ? 0.82 : 1;
          var cost = best[k - 1][j].cost + (w / max) * (w / max) * eased;
          if (cost < best[k][i].cost)
            best[k][i] = {
              cost: cost,
              from: j
            };
        }
      }
    }
    if (best[groups][n].cost === Infinity)
      continue;
    var out = [];
    for (k = groups, i = n; k > 0; k--) {
      out.unshift([best[k][i].from, i]);
      i = best[k][i].from;
    }
    return out;
  }
  return [[0, n]];
}

// A song's lines (Parse.js's shape) as the phrases the pill shows, in order. `measure` gives a
// text's width in px in the pill's face; `max` is the widest the words may be.
function phrases(lines, measure, max) {
  var space = measure(" ");
  var out = [];
  for (var li = 0; li < lines.length; li++) {
    var line = lines[li];
    var texts = line.words.map(function (w) {
      return w.text;
    });
    var widths = texts.map(measure);
    var parts = cuts(texts, widths, space, max);
    for (var p = 0; p < parts.length; p++) {
      var words = line.words.slice(parts[p][0], parts[p][1]);
      var last = words[words.length - 1];
      var whole = p === parts.length - 1;
      var width = 0;
      for (var i = parts[p][0]; i < parts[p][1]; i++)
        width += widths[i] + (i > parts[p][0] ? space : 0);
      out.push({
        line: li,
        t: words[0].t,
        end: whole ? line.end : last.t + last.d,
        // A stretch of a line gives way to the next stretch as that one is sung.
        out: whole ? line.out : line.words[parts[p][1]].t,
        text: words.map(function (w) {
          return w.text;
        }).join(" "),
        width: width,
        words: words
      });
    }
  }
  function follows(a, b) {
    return a.out >= b.t - 0.001;
  }
  for (var k = 0; k < out.length; k++) {
    var ph = out[k];
    var prev = k > 0 ? out[k - 1] : null;
    var next = k + 1 < out.length ? out[k + 1] : null;
    ph.fromRest = !(prev && follows(prev, ph));
    ph.toRest = !(next && follows(ph, next));
    // Never before the phrase in front has been sung through, unless the two truly run together.
    ph.start = ph.fromRest ? ph.t - LEAD : Math.max(Math.min(prev.end, ph.t), ph.t - LEAD);
  }
  for (k = 0; k < out.length; k++)
    out[k].stop = out[k].toRest ? out[k].out : out[k + 1].start;
  return out;
}

// The last phrase whose `key` moment has come, or -1.
function last(list, now, key) {
  var lo = 0, hi = list.length - 1, found = -1;
  while (lo <= hi) {
    var mid = (lo + hi) >> 1;
    if (key(list[mid]) <= now) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return found;
}

// The phrase the pill is wide for at `now`, or -1 when it is the plain pill.
function wideFor(list, now) {
  var i = last(list, now, function (p) {
    return p.start - (p.fromRest ? EARLY : 0);
  });
  if (i < 0)
    return -1;
  return now < list[i].stop + (list[i].toRest ? LATE : 0) ? i : -1;
}

// The last phrase to have come up by `now`, or -1: it and the one before it are all that can be
// on screen.
function latest(list, now) {
  return last(list, now, function (p) {
    return p.start;
  });
}

// ---- one word at one moment ----

// How much of the word has been sung, 0..1.
function fill(word, now) {
  return word ? clamp01((now - word.t) / Math.max(0.05, word.d)) : 0;
}

// The word being sung stands a little proud of the line: 0 at rest, 1 while it is held.
function swell(word, now) {
  if (!word || now < word.t)
    return 0;
  return smooth((now - word.t) / Math.max(0.04, Math.min(RISE, word.d * 0.5))) * (1 - smooth((now - (word.t + word.d)) / FALL));
}

// 0 as the word's last letter is sung, 1 once it has eased back among the sung.
function settled(word, now) {
  return word ? smooth((now - (word.t + word.d)) / SETTLE) : 0;
}

// How much a word is leant on, 0..1, by how long it is held.
function weight(word) {
  return word ? clamp01((word.d - HELD_FROM) / (HELD_FULL - HELD_FROM)) : 0;
}

// The `index`th word's way in, 0..1 and eased, and how far through its way out the whole
// phrase is, 0..1 and even: the line fades early in it and moves late (Lyrics/LyricLine.qml),
// so the line coming up under it is never read through it.
function arrived(phrase, index, now) {
  return phrase ? outCubic((now - (phrase.start + (phrase.fromRest ? 0 : FOLLOW) + index * STAGGER)) / ARRIVE) : 0;
}

function left(phrase, now) {
  return phrase ? clamp01((now - phrase.stop) / LEAVE) : 1;
}

function escaped(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function hex2(x) {
  var h = Math.round(clamp01(x) * 255).toString(16);
  return h.length < 2 ? "0" + h : h;
}

// The word as styled text, `sung` of the way through: each letter lit from `unlit` to `lit`
// (alphas of the ink `rgb`, "rrggbb") as a front SOFT letters wide passes over it.
function swept(text, sung, rgb, unlit, lit) {
  var s = String(text);
  var front = sung * (s.length - 1 + SOFT);
  var out = "", run = "", tone = "";
  for (var i = 0; i < s.length; i++) {
    var a = hex2(unlit + (lit - unlit) * smooth((front - i) / SOFT));
    if (a !== tone && run !== "") {
      out += '<font color="#' + tone + rgb + '">' + escaped(run) + "</font>";
      run = "";
    }
    tone = a;
    run += s.charAt(i);
  }
  if (run !== "")
    out += '<font color="#' + tone + rgb + '">' + escaped(run) + "</font>";
  return out;
}
