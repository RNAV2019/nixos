.pragma library

// Colour values for the picker's four rows, in CSS Color 4 syntax so each pastes as it is.

function parseHex(hex) {
  var m = /^#?([0-9a-f]{6})$/i.exec(String(hex).trim());
  if (!m)
    return null;
  var n = parseInt(m[1], 16);
  return {
    r: (n >> 16) & 255,
    g: (n >> 8) & 255,
    b: n & 255
  };
}

function toHex(c) {
  function h(v) {
    var s = v.toString(16).toUpperCase();
    return s.length < 2 ? "0" + s : s;
  }
  return "#" + h(c.r) + h(c.g) + h(c.b);
}

function normalise(hex) {
  var c = parseHex(hex);
  return c ? toHex(c) : "";
}

function rgbString(c) {
  return "rgb(" + c.r + " " + c.g + " " + c.b + ")";
}

function hslString(c) {
  var r = c.r / 255, g = c.g / 255, b = c.b / 255;
  var max = Math.max(r, g, b), min = Math.min(r, g, b);
  var l = (max + min) / 2;
  var d = max - min;
  var h = 0, s = 0;
  if (d > 0) {
    s = d / (1 - Math.abs(2 * l - 1));
    if (max === r)
      h = ((g - b) / d) % 6;
    else if (max === g)
      h = (b - r) / d + 2;
    else
      h = (r - g) / d + 4;
    h = h * 60;
    if (h < 0)
      h += 360;
  }
  return "hsl(" + Math.round(h) % 360 + " " + Math.round(s * 100) + "% " + Math.round(l * 100) + "%)";
}

function linear(v) {
  v = v / 255;
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

// sRGB to OKLab and on to its polar form (Ottosson, 2020); L is 0..1.
function oklab(c) {
  var r = linear(c.r), g = linear(c.g), b = linear(c.b);
  var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return {
    L: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  };
}

function oklchString(c) {
  var lab = oklab(c);
  var chroma = Math.sqrt(lab.a * lab.a + lab.b * lab.b);
  var h = chroma < 0.0004 ? 0 : Math.atan2(lab.b, lab.a) * 180 / Math.PI;
  if (h < 0)
    h += 360;
  return "oklch(" + (Math.round(lab.L * 1000) / 10) + "% " + chroma.toFixed(3) + " " + Math.round(h) % 360 + ")";
}

// The four rows, in the order the picker lists them.
function formats(hex) {
  var c = parseHex(hex);
  if (!c)
    return [];
  return [
    {
      label: "HEX",
      value: toHex(c)
    },
    {
      label: "RGB",
      value: rgbString(c)
    },
    {
      label: "HSL",
      value: hslString(c)
    },
    {
      label: "OKLCH",
      value: oklchString(c)
    }
  ];
}

// How far apart two colours read, as OKLab lightness; the swatch gets an edge when this is small.
function lightnessGap(hexA, hexB) {
  var a = parseHex(hexA), b = parseHex(hexB);
  if (!a || !b)
    return 1;
  return Math.abs(oklab(a).L - oklab(b).L);
}
