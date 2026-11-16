.pragma library

// The stage's colours, read off the playing song's cover. No QML imports:
// tools/lyrics-test.mjs evaluates this file under node.
//
// In: the cover's few most common colours as { h, s, l } (hue, saturation and lightness, each
// 0..1), in any order. Out: the parts those colours play, in the same form:
//   accent   the cover's liveliest colour, lifted until it reads on black: the word in hand
//   ink      what words are set in: near white, leaning the cover's way
//   dim      a word not yet sung
//   wash     the three colours the ground is lit with: the cover's own, at their own hue and
//            saturation, the one the cover has most of first. Unlike the parts above they are
//            not lifted to read as type, so a deep blue sleeve lights the ground deep blue
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

// A colour of the cover as light for the ground: its own hue, a little more than its own
// saturation, and the lightness at which that saturation is at its fullest. How bright the
// ground is belongs to the stage, not to the cover.
function light(c) {
  return {
    h: c.h,
    s: clamp(c.s * 1.2, 0, 1),
    l: 0.5
  };
}

// The three the ground is lit with, from the cover's colours that count as colours. The first is
// the hue the cover has most of: the quantiser hands back a few colours of about equal share,
// so the hue most of them fall near is the one that covers the most of the sleeve.
function wash(coloured) {
  var main = coloured[0], mainScore = -1;
  coloured.forEach(function (c) {
    var near = 0;
    coloured.forEach(function (d) {
      if (hueGap(c.h, d.h) < 0.07)
        near++;
    });
    var score = near + c.s * 0.5;
    if (score > mainScore) {
      main = c;
      mainScore = score;
    }
  });
  // The furthest from it that the cover has, and a third apart from both.
  var far = null, farScore = 0;
  coloured.forEach(function (c) {
    var gap = hueGap(c.h, main.h);
    if (gap >= 0.06 && gap * (0.3 + c.s) > farScore) {
      far = c;
      farScore = gap * (0.3 + c.s);
    }
  });
  var rest = null, restScore = 0;
  coloured.forEach(function (c) {
    var gap = Math.min(hueGap(c.h, main.h), far !== null ? hueGap(c.h, far.h) : 1);
    if (gap >= 0.04 && gap * (0.3 + c.s) > restScore) {
      rest = c;
      restScore = gap * (0.3 + c.s);
    }
  });
  // A sleeve of one hue is lit with that hue alone, in three depths, not with neighbours it
  // does not have.
  var second = far !== null ? light(far) : {
    h: main.h,
    s: clamp(main.s * 1.2, 0, 1),
    l: 0.36
  };
  var third = rest !== null ? light(rest) : far !== null ? {
    h: main.h,
    s: clamp(main.s * 1.2, 0, 1),
    l: 0.38
  } : {
    h: main.h,
    s: clamp(main.s, 0, 1),
    l: 0.62
  };
  return [light(main), second, third];
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
      ink: {
        h: lightest.h,
        s: tint,
        l: 0.94
      },
      dim: {
        h: lightest.h,
        s: tint,
        l: 0.5
      },
      wash: [{
          h: lightest.h,
          s: tint,
          l: 0.6
        }, {
          h: lightest.h,
          s: tint,
          l: 0.42
        }, {
          h: lightest.h,
          s: tint,
          l: 0.3
        }]
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

  var accent = lift(best);
  return {
    found: true,
    accent: accent,
    ink: {
      h: accent.h,
      s: clamp(accent.s * 0.45, 0.14, 0.4),
      l: 0.94
    },
    dim: {
      h: accent.h,
      s: clamp(accent.s * 0.4, 0.12, 0.34),
      l: 0.56
    },
    wash: wash(coloured)
  };
}
