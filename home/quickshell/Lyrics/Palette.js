.pragma library

// The stage's colours, read off the playing song's cover. No QML imports:
// tools/lyrics-test.mjs evaluates this file under node.
//
// In: the cover's few most common colours as { h, s, l } (hue, saturation and lightness, each
// 0..1), in any order. Out: the parts those colours play, in the same form:
//   accent   the cover's liveliest colour, lifted until it reads on black: the word in hand
//   second   the colour furthest from it round the wheel that the cover really has
//   third    another the cover has, or one between the two
//   ink      what words are set in: near white, leaning the cover's way
//   dim      a word not yet sung
//   found    false when the cover has no colour to speak of (a black-and-white sleeve), and
//            every part is then a grey, which is as true to it
// With no cover at all (an empty list) it answers null, and the stage falls back on the theme.

function hueGap(a, b) {
  var d = Math.abs(a - b) % 1;
  return d > 0.5 ? 1 - d : d;
}

function clamp(x, lo, hi) {
  return x < lo ? lo : x > hi ? hi : x;
}

// Bright and saturated enough to stand as type on black.
function lift(c) {
  return {
    h: c.h,
    s: clamp(c.s, 0.5, 0.9),
    l: clamp(c.l, 0.66, 0.78)
  };
}

function roles(colors) {
  if (!colors || colors.length === 0)
    return null;

  // What counts as a colour: not grey, and neither black nor white.
  var coloured = colors.filter(function (c) {
    return c.s >= 0.18 && c.l >= 0.1 && c.l <= 0.92;
  });

  if (coloured.length === 0) {
    var lightest = colors.reduce(function (a, b) {
      return b.l > a.l ? b : a;
    });
    var tint = clamp(lightest.s, 0, 0.08);
    return {
      found: false,
      accent: {
        h: lightest.h,
        s: tint,
        l: 0.86
      },
      second: {
        h: lightest.h,
        s: tint,
        l: 0.68
      },
      third: {
        h: lightest.h,
        s: tint,
        l: 0.5
      },
      ink: {
        h: lightest.h,
        s: tint,
        l: 0.94
      },
      dim: {
        h: lightest.h,
        s: tint,
        l: 0.5
      }
    };
  }

  // The liveliest: saturated, and nearer the middle of the light than either end.
  var best = coloured[0], bestScore = -1;
  coloured.forEach(function (c) {
    var score = c.s * (0.45 + 1 - Math.abs(c.l - 0.55) * 1.5);
    if (score > bestScore) {
      best = c;
      bestScore = score;
    }
  });

  // The furthest from it that the cover has, if the cover has one far enough to tell apart.
  var other = null, otherScore = 0;
  coloured.forEach(function (c) {
    var gap = hueGap(c.h, best.h);
    var score = gap * (0.3 + c.s);
    if (gap >= 0.06 && score > otherScore) {
      other = c;
      otherScore = score;
    }
  });
  var second = other !== null ? other : {
    h: (best.h + 0.09) % 1,
    s: best.s,
    l: best.l
  };

  // A third apart from both, or failing that one between them.
  var spare = null, spareScore = 0;
  coloured.forEach(function (c) {
    var gap = Math.min(hueGap(c.h, best.h), hueGap(c.h, second.h));
    if (gap >= 0.05 && gap * (0.3 + c.s) > spareScore) {
      spare = c;
      spareScore = gap * (0.3 + c.s);
    }
  });
  var third = spare !== null ? spare : {
    h: (best.h + 1 - 0.07) % 1,
    s: best.s * 0.8,
    l: best.l
  };

  var accent = lift(best);
  return {
    found: true,
    accent: accent,
    second: lift(second),
    third: lift(third),
    ink: {
      h: accent.h,
      s: clamp(accent.s * 0.45, 0.14, 0.4),
      l: 0.94
    },
    dim: {
      h: accent.h,
      s: clamp(accent.s * 0.4, 0.12, 0.34),
      l: 0.56
    }
  };
}
