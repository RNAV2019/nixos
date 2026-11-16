.pragma library

// The curves the lyric styles are drawn with. Everything on the stage is a function of the
// song's own time, so a style asks "how far along is this word?" and never keeps a running
// animation: a seek, a pause or a pinned test frame all land on the same picture.

function clamp01(x) {
  return x < 0 ? 0 : x > 1 ? 1 : x;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

// How far `x` is from `a` to `b`, 0..1.
function span(a, b, x) {
  // A stretch with no length (or none yet: both ends at infinity) is a step at its end.
  if (!(b - a > 0))
    return x >= b ? 1 : 0;
  return clamp01((x - a) / (b - a));
}

function smooth(a, b, x) {
  var t = span(a, b, x);
  return t * t * (3 - 2 * t);
}

function outCubic(t) {
  t = clamp01(t);
  var u = 1 - t;
  return 1 - u * u * u;
}

function outQuint(t) {
  t = clamp01(t);
  var u = 1 - t;
  return 1 - u * u * u * u * u;
}

function inCubic(t) {
  t = clamp01(t);
  return t * t * t;
}

function inOut(t) {
  t = clamp01(t);
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

// Past the end by `s` (1.7 is the classic, about 10%) and back.
function outBack(t, s) {
  t = clamp01(t);
  var k = s === undefined ? 1.7 : s;
  var u = t - 1;
  return 1 + (k + 1) * u * u * u + k * u * u;
}

// A spring let go at 0 towards 1, `age` seconds later. zeta below 1 rings; 0 before it starts.
function spring(age, omega, zeta) {
  if (age <= 0)
    return 0;
  if (zeta >= 1)
    return 1 - (1 + omega * age) * Math.exp(-omega * age);
  var wd = omega * Math.sqrt(1 - zeta * zeta);
  return 1 - Math.exp(-zeta * omega * age) * (Math.cos(wd * age) + zeta * omega / wd * Math.sin(wd * age));
}

// A hit that dies away: 1 at the moment, e^-1 after 1/decay seconds, 0 before.
function pulse(age, decay) {
  return age < 0 ? 0 : Math.exp(-age * decay);
}

// A repeatable number in 0..1 from a seed and up to two indices.
function hash(seed, i, j) {
  var h = (seed >>> 0) ^ Math.imul((i | 0) + 1, 374761393) ^ Math.imul((j | 0) + 1, 668265263);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

// -1..1.
function jitter(seed, i, j) {
  return hash(seed, i, j) * 2 - 1;
}

function pick(list, seed, i, j) {
  return list[Math.min(list.length - 1, Math.floor(hash(seed, i, j) * list.length))];
}

// Where a word is in its life, for a style to shape:
//   age     seconds since it began (negative before)
//   p       0..1 through its own length
//   sung    it has ended
function life(word, now) {
  var age = now - word.t;
  return {
    age: age,
    p: clamp01(age / Math.max(0.05, word.d)),
    sung: age >= word.d
  };
}

// How loudly a word should land, 0..1: long notes and the ends of lines carry the weight.
function weight(word, isLast) {
  return clamp01(0.25 + Math.min(word.d, 1.6) * 0.42 + (isLast ? 0.2 : 0));
}

// The letters of a word with what is not a letter taken off its ends ("night," -> "night").
function bare(text) {
  return String(text).replace(/^[^\wÀ-ÿ']+|[^\wÀ-ÿ']+$/g, "");
}

// A line's words dealt into rows of about equal length, for a style that sets a line as a
// block: one row for a word or two, up to four for a long line. Returns rows of word indices.
function rows(words) {
  var n = words.length <= 2 ? 1 : words.length <= 4 ? 2 : words.length <= 7 ? 3 : 4;
  var total = 0;
  var lengths = words.map(function (w) {
    var l = bare(w.text).length + 1;
    total += l;
    return l;
  });
  var out = [];
  var row = [];
  var run = 0;
  var done = 0;
  for (var i = 0; i < words.length; i++) {
    row.push(i);
    run += lengths[i];
    var rowsLeft = n - out.length - 1;
    var wordsLeft = words.length - i - 1;
    // Close the row once it has its share, or when the words left are only enough for one
    // each of the rows left.
    if (rowsLeft > 0 && (done + run >= total * (out.length + 1) / n - lengths[i] / 2 || wordsLeft <= rowsLeft)) {
      out.push(row);
      row = [];
      done += run;
      run = 0;
    }
  }
  if (row.length > 0)
    out.push(row);
  return out;
}
