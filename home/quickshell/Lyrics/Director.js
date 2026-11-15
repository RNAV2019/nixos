.pragma library

// Cuts a song into the stretches the lyric stage plays in one style each, and casts a style for
// every stretch. No QML imports: tools/lyrics-test.mjs evaluates this file under node.
//
// A segment: { index, style, tier, t0, t1, firstLine, lastLine, seed }. Between t0 and t1 the
// style draws lines firstLine..lastLine and no others. A stretch with nothing sung (the intro,
// a solo, the fade) is a segment too, in the style named `Interlude`, with firstLine -1.

// A segment starts this long before its first word, so the cut lands just ahead of the voice
// and the line before it is not left a dark moment short.
var LEAD = 0.15;
// Nothing sung for this long is an interlude.
var GAP = 6.5;
// A style is held about this long, and for this many lines at most.
var HOLD_SECONDS = 8.5;
var HOLD_LINES = 5;

// The same 32-bit hash everywhere a seed is made from text.
function hashText(text) {
  var h = 2166136261;
  var s = String(text);
  for (var i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// mulberry32: a small generator, so one song is always cast the same way.
function rng(seed) {
  var a = seed >>> 0;
  return function () {
    a = (a + 0x6D2B79F5) >>> 0;
    var t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Runs of lines that belong together: one part, with no long silence inside.
function runs(model) {
  var out = [];
  var lines = model.lines;
  for (var i = 0; i < lines.length; i++) {
    var open = out.length > 0 ? out[out.length - 1] : null;
    var silent = i > 0 && lines[i].t - lines[i - 1].end > GAP;
    if (!open || silent || lines[i].part !== lines[i - 1].part)
      out.push({
        first: i,
        last: i,
        part: lines[i].part
      });
    else
      open.last = i;
  }
  return out;
}

// One run as stretches of about HOLD_SECONDS, never leaving a single line over at the end.
function chunks(model, run) {
  var out = [];
  var lines = model.lines;
  var first = run.first;
  for (var i = run.first; i <= run.last; i++) {
    var count = i - first + 1;
    var long = lines[i].end - lines[first].t >= HOLD_SECONDS && count >= 2;
    var left = run.last - i;
    if ((long || count >= HOLD_LINES) && left >= 2) {
      out.push({
        first: first,
        last: i
      });
      first = i + 1;
    }
  }
  if (first <= run.last)
    out.push({
      first: first,
      last: run.last
    });
  return out;
}

function emojiCount(model, first, last) {
  var n = 0;
  for (var i = first; i <= last; i++)
    model.lines[i].words.forEach(function (w) {
      if (w.emoji)
        n++;
    });
  return n;
}

// The whole plan. `catalogue` lists the styles: { name, tiers: [tier], weight, wants }, where
// `wants: "emoji"` keeps a style for stretches that have pictures to show. A style is not cast
// again until three others have played, where the tier has that many to choose from. A style
// may name a `look` (the black-and-white film styles do); one that shares the last style's look
// is twice as likely to follow it and one that does not half as likely, so looks come in runs.
function plan(model, catalogue, seed) {
  var segments = [];
  var lines = model.lines;
  var next = rng(seed);
  var recent = [];
  var lastLook = null;

  // A style's chance: its weight, leant towards staying in the look the song is in.
  function chance(s) {
    var w = s.weight || 1;
    if (lastLook === null)
      return w;
    return (s.look || "") === lastLook ? w * 2 : w * 0.5;
  }

  function cast(tier, first, last) {
    var pictures = emojiCount(model, first, last);
    var pool = catalogue.filter(function (s) {
      return s.tiers.indexOf(tier) !== -1 && (s.wants !== "emoji" || pictures >= 2);
    });
    if (pool.length === 0)
      pool = catalogue.filter(function (s) {
        return s.wants !== "emoji";
      });
    var fresh = pool;
    for (var keep = Math.min(3, recent.length); keep > 0; keep--) {
      var barred = recent.slice(-keep);
      var open = pool.filter(function (s) {
        return barred.indexOf(s.name) === -1;
      });
      if (open.length > 0) {
        fresh = open;
        break;
      }
    }
    var total = 0;
    fresh.forEach(function (s) {
      total += chance(s);
    });
    var roll = next() * total;
    var chosen = fresh[fresh.length - 1];
    for (var i = 0; i < fresh.length; i++) {
      roll -= chance(fresh[i]);
      if (roll <= 0) {
        chosen = fresh[i];
        break;
      }
    }
    recent.push(chosen.name);
    lastLook = chosen.look || "";
    return chosen.name;
  }

  function interlude(t0, t1) {
    segments.push({
      style: "Interlude",
      tier: "calm",
      t0: t0,
      t1: t1,
      firstLine: -1,
      lastLine: -1
    });
  }

  if (lines.length === 0) {
    interlude(-Infinity, Infinity);
  } else {
    if (lines[0].t - LEAD > 3)
      interlude(-Infinity, lines[0].t - LEAD);
    runs(model).forEach(function (run) {
      var tier = model.parts[run.part] ? model.parts[run.part].tier : "mid";
      chunks(model, run).forEach(function (c) {
        var t0 = lines[c.first].t - LEAD;
        var prev = segments.length > 0 ? segments[segments.length - 1] : null;
        if (prev && prev.firstLine !== -1) {
          var done = lines[prev.lastLine].out + 0.3;
          if (t0 - done > 2.5) {
            prev.t1 = done;
            interlude(done, t0);
          } else {
            prev.t1 = t0;
          }
        }
        segments.push({
          style: cast(tier, c.first, c.last),
          tier: tier,
          t0: segments.length === 0 ? -Infinity : t0,
          t1: Infinity,
          firstLine: c.first,
          lastLine: c.last
        });
      });
    });
    var end = segments[segments.length - 1];
    end.t1 = lines[end.lastLine].out + 0.3;
    interlude(end.t1, Infinity);
  }
  segments.forEach(function (s, i) {
    s.index = i;
    s.seed = (seed ^ Math.imul(i + 1, 2654435761)) >>> 0;
  });
  return segments;
}

// The index of the segment playing at `now`.
function segmentAt(segments, now) {
  for (var i = segments.length - 1; i >= 0; i--)
    if (now >= segments[i].t0)
      return i;
  return 0;
}
