pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The launcher's '=' mode. Colours and integer bases are answered here in JS; clock and
// calendar questions go to GNU date, and everything else (arithmetic, units, currency) to
// qalc. Each result is a row: `name` is shown, `copy` goes to the clipboard.
Singleton {
  id: root

  // The query with its '=' already stripped.
  property string query: ""

  property var results: []

  readonly property string expr: query.trim()

  // qalc runs on a private config so its mode never touches the user's own qalc.cfg:
  // no mixed units ("3 mi + 188 yd"), no prompts, nothing saved on exit.
  readonly property string qalcHome: Paths.home + "/.cache/quickshell/qalc"
  readonly property string qalcConfig: "[General]\nsave_config=0\nsave_mode_on_exit=0\nsave_definitions_on_exit=0\nauto_update_exchange_rates=0\ncolorize=0\n[Mode]\nmixed_units_conversion=0\n"

  onExprChanged: compute()

  function compute() {
    var q = root.expr;
    var hit;

    root.qalcFor = "";
    root.dateFor = "";

    if (q.length === 0) {
      root.results = [];
      return;
    }

    hit = colourRows(q);
    if (hit) {
      root.results = hit;
      return;
    }

    hit = baseRows(q);
    if (hit) {
      root.results = hit;
      return;
    }

    hit = dateCommand(q);
    if (hit) {
      root.dateKind = hit.kind;
      root.dateLabel = hit.label;
      root.dateZone = hit.zone || "";
      root.dateArgs = hit.args;
      root.dateFor = q;
      date.run();
      return;
    }

    root.qalcFor = q;
    qalc.run();
  }

  function row(id, name, desc, extra) {
    var r = {
      id: "calc:" + id,
      name: name,
      desc: desc,
      copy: name,
      glyph: "",
      swatch: ""
    };
    for (var k in extra)
      r[k] = extra[k];
    return r;
  }

  // --- Colours ------------------------------------------------------------------------

  function clamp(v, lo, hi) {
    return Math.min(hi, Math.max(lo, v));
  }

  // A CSS number: "50%" is read against `full`, a bare number as is.
  function num(s, full) {
    s = String(s).trim();
    if (!/^[-+]?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?%?$/i.test(s))
      return NaN;
    if (s.endsWith("%"))
      return parseFloat(s) / 100 * full;
    return parseFloat(s);
  }

  // hsl()'s saturation and lightness: "57%" or, as CSS Color 4 allows, a bare 57.
  function pct(s) {
    return String(s).trim().endsWith("%") ? num(s, 1) : num(s, 100) / 100;
  }

  // A CSS colour function's arguments, comma or space separated, alpha after a slash.
  function args(body) {
    var alpha = "1";
    var slash = body.split("/");
    if (slash.length === 2) {
      body = slash[0];
      alpha = slash[1].trim();
    } else if (slash.length > 2) {
      return null;
    }
    var parts = body.trim().split(/\s*,\s*|\s+/);
    if (parts.length === 4 && slash.length === 1)
      alpha = parts.pop();
    if (parts.length !== 3)
      return null;
    return {
      parts: parts,
      alpha: num(alpha, 1)
    };
  }

  // Everything is held as sRGB 0-1 plus alpha.
  function parseColour(q) {
    var s = q.toLowerCase();
    var m, a;

    m = s.match(/^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/);
    if (m) {
      var h = m[1];
      if (h.length <= 4)
        h = h.replace(/./g, "$&$&");
      return {
        r: parseInt(h.substr(0, 2), 16) / 255,
        g: parseInt(h.substr(2, 2), 16) / 255,
        b: parseInt(h.substr(4, 2), 16) / 255,
        a: h.length === 8 ? parseInt(h.substr(6, 2), 16) / 255 : 1
      };
    }

    m = s.match(/^rgba?\((.*)\)$/);
    if (m && (a = args(m[1]))) {
      var c = {
        r: num(a.parts[0], 255) / 255,
        g: num(a.parts[1], 255) / 255,
        b: num(a.parts[2], 255) / 255,
        a: a.alpha
      };
      return valid(c) ? c : null;
    }

    m = s.match(/^hsla?\((.*)\)$/);
    if (m && (a = args(m[1]))) {
      var hsl = hslToRgb(parseFloat(a.parts[0]), pct(a.parts[1]), pct(a.parts[2]));
      hsl.a = a.alpha;
      return valid(hsl) ? hsl : null;
    }

    m = s.match(/^oklch\((.*)\)$/);
    if (m && (a = args(m[1]))) {
      var lab = oklchToRgb(num(a.parts[0], 1), num(a.parts[1], 0.4), parseFloat(a.parts[2]));
      if (!lab)
        return null;
      lab.a = a.alpha;
      return valid(lab) ? lab : null;
    }

    // CSS names, read through Qt's own SVG colour table. A word Qt does not know
    // throws or comes back invalid, and falls through to qalc.
    if (/^[a-z]{3,}$/.test(s)) {
      try {
        var named = Qt.color(s);
        if (named && named.valid !== false)
          return {
            r: named.r,
            g: named.g,
            b: named.b,
            a: named.a,
            name: s
          };
      } catch (e) {}
    }
    return null;
  }

  function valid(c) {
    return [c.r, c.g, c.b, c.a].every(function (v) {
      return isFinite(v);
    });
  }

  function hslToRgb(h, s, l) {
    h = ((h % 360) + 360) % 360;
    s = clamp(s, 0, 1);
    l = clamp(l, 0, 1);
    var k = function (n) {
      return (n + h / 30) % 12;
    };
    var a = s * Math.min(l, 1 - l);
    var f = function (n) {
      return l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1));
    };
    return {
      r: f(0),
      g: f(8),
      b: f(4)
    };
  }

  function rgbToHsl(c) {
    var max = Math.max(c.r, c.g, c.b);
    var min = Math.min(c.r, c.g, c.b);
    var l = (max + min) / 2;
    var d = max - min;
    var h = 0, s = 0;
    if (d > 0) {
      s = d / (1 - Math.abs(2 * l - 1));
      if (max === c.r)
        h = 60 * (((c.g - c.b) / d) % 6);
      else if (max === c.g)
        h = 60 * ((c.b - c.r) / d + 2);
      else
        h = 60 * ((c.r - c.g) / d + 4);
    }
    return {
      h: (h + 360) % 360,
      s: s,
      l: l
    };
  }

  // Björn Ottosson's OKLab, via linear sRGB.
  function toLinear(v) {
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  }

  function fromLinear(v) {
    return v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
  }

  function rgbToOklch(c) {
    var r = toLinear(c.r), g = toLinear(c.g), b = toLinear(c.b);
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    var L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    var A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    var B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    var C = Math.sqrt(A * A + B * B);
    var H = C < 1e-4 ? 0 : (Math.atan2(B, A) * 180 / Math.PI + 360) % 360;
    return {
      l: L,
      c: C,
      h: H
    };
  }

  // Out-of-gamut input is clipped per channel and flagged, so the swatch and the other
  // formats say what the screen can actually show.
  function oklchToRgb(L, C, H) {
    if (!isFinite(L) || !isFinite(C) || !isFinite(H))
      return null;
    var A = C * Math.cos(H * Math.PI / 180);
    var B = C * Math.sin(H * Math.PI / 180);
    var l = Math.pow(L + 0.3963377774 * A + 0.2158037573 * B, 3);
    var m = Math.pow(L - 0.1055613458 * A - 0.0638541728 * B, 3);
    var s = Math.pow(L - 0.0894841775 * A - 1.2914855480 * B, 3);
    var rgb = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s].map(fromLinear);
    var clipped = rgb.some(function (v) {
      return v < -0.0005 || v > 1.0005;
    });
    return {
      r: clamp(rgb[0], 0, 1),
      g: clamp(rgb[1], 0, 1),
      b: clamp(rgb[2], 0, 1),
      clipped: clipped
    };
  }

  function fixed(v, places) {
    return String(parseFloat(v.toFixed(places)));
  }

  function colourRows(q) {
    var c = parseColour(q);
    if (!c)
      return null;

    var byte = function (v) {
      return Math.round(clamp(v, 0, 1) * 255);
    };
    var hex2 = function (v) {
      return ("0" + v.toString(16)).slice(-2);
    };
    var alpha = c.a < 1 ? fixed(clamp(c.a, 0, 1), 3) : "";
    var r = byte(c.r), g = byte(c.g), b = byte(c.b);
    var hsl = rgbToHsl({
      r: r / 255,
      g: g / 255,
      b: b / 255
    });
    var ok = rgbToOklch(c);

    var hex = "#" + hex2(r) + hex2(g) + hex2(b) + (alpha ? hex2(byte(c.a)) : "");
    var rgb = alpha ? "rgba(" + [r, g, b, alpha].join(", ") + ")" : "rgb(" + [r, g, b].join(", ") + ")";
    var hs = [Math.round(hsl.h), Math.round(hsl.s * 100) + "%", Math.round(hsl.l * 100) + "%"];
    var hslText = alpha ? "hsla(" + hs.concat([alpha]).join(", ") + ")" : "hsl(" + hs.join(", ") + ")";
    var oklch = "oklch(" + [fixed(ok.l, 3), fixed(ok.c, 3), fixed(ok.h, 1)].join(" ") + (alpha ? " / " + alpha : "") + ")";

    var swatch = hex.length === 9 ? "#" + hex.substr(7, 2) + hex.substr(1, 6) : hex;
    var note = c.clipped ? " · clipped to sRGB" : c.name ? " · " + c.name : "";
    var extra = {
      swatch: swatch
    };
    return [row("hex", hex, "HEX" + note, extra), row("rgb", rgb, "RGB" + note, extra), row("hsl", hslText, "HSL" + note, extra), row("oklch", oklch, "OKLCH" + note, extra)];
  }

  // --- Number bases ---------------------------------------------------------------------

  readonly property var bases: ({
      hex: {
        radix: 16,
        prefix: "0x",
        label: "Hexadecimal"
      },
      dec: {
        radix: 10,
        prefix: "",
        label: "Decimal"
      },
      oct: {
        radix: 8,
        prefix: "0o",
        label: "Octal"
      },
      bin: {
        radix: 2,
        prefix: "0b",
        label: "Binary"
      }
    })

  // An integer literal in any base, optionally "to <base>": the target leads, the rest
  // follow. Past 2^53 a JS number stops being exact, so those go to qalc instead.
  function baseRows(q) {
    var m = q.toLowerCase().replace(/[_\s](?=[0-9a-f])/g, "").match(/^(0x[0-9a-f]+|0b[01]+|0o[0-7]+|\d+)(?:\s*(?:to|in|as)\s*(hex|hexadecimal|dec|decimal|oct|octal|bin|binary|bases?))?$/);
    if (!m)
      return null;
    var lit = m[1];
    var target = m[2] ? m[2].substr(0, 3) : "";

    // A bare decimal integer is arithmetic, not a base question.
    if (/^\d+$/.test(lit) && !target)
      return null;

    var n = lit.startsWith("0x") ? parseInt(lit.substr(2), 16) : lit.startsWith("0b") ? parseInt(lit.substr(2), 2) : lit.startsWith("0o") ? parseInt(lit.substr(2), 8) : parseInt(lit, 10);
    if (!Number.isSafeInteger(n))
      return null;

    var order = ["dec", "hex", "bin", "oct"];
    if (target && target !== "bas") {
      order.splice(order.indexOf(target), 1);
      order.unshift(target);
    }
    return order.map(function (key) {
      var base = root.bases[key];
      var digits = n.toString(base.radix);
      return row("base-" + key, base.prefix + (key === "hex" ? digits.toUpperCase() : digits), base.label, {
        glyph: Icons.numberBase
      });
    });
  }

  // --- Time zones and dates -------------------------------------------------------------

  // City name to zone, built from tzdata's own zone and link names.
  property var zones: ({})

  // What tzdata does not spell: abbreviations and cities that share a zone.
  readonly property var zoneAliases: ({
      utc: "UTC",
      gmt: "Etc/GMT",
      z: "UTC",
      bst: "Europe/London",
      uk: "Europe/London",
      britain: "Europe/London",
      england: "Europe/London",
      ireland: "Europe/Dublin",
      cet: "Europe/Paris",
      cest: "Europe/Paris",
      eet: "Europe/Athens",
      est: "America/New_York",
      edt: "America/New_York",
      et: "America/New_York",
      cst: "America/Chicago",
      cdt: "America/Chicago",
      ct: "America/Chicago",
      mst: "America/Denver",
      mdt: "America/Denver",
      pst: "America/Los_Angeles",
      pdt: "America/Los_Angeles",
      pt: "America/Los_Angeles",
      akst: "America/Anchorage",
      hst: "Pacific/Honolulu",
      ist: "Asia/Kolkata",
      jst: "Asia/Tokyo",
      kst: "Asia/Seoul",
      sgt: "Asia/Singapore",
      hkt: "Asia/Hong_Kong",
      aest: "Australia/Sydney",
      aedt: "Australia/Sydney",
      awst: "Australia/Perth",
      nzst: "Pacific/Auckland",
      nzdt: "Pacific/Auckland",
      sast: "Africa/Johannesburg",
      nyc: "America/New_York",
      "new york city": "America/New_York",
      boston: "America/New_York",
      washington: "America/New_York",
      miami: "America/New_York",
      atlanta: "America/New_York",
      "san francisco": "America/Los_Angeles",
      sf: "America/Los_Angeles",
      la: "America/Los_Angeles",
      seattle: "America/Los_Angeles",
      "las vegas": "America/Los_Angeles",
      dallas: "America/Chicago",
      houston: "America/Chicago",
      austin: "America/Chicago",
      toronto: "America/Toronto",
      montreal: "America/Toronto",
      beijing: "Asia/Shanghai",
      china: "Asia/Shanghai",
      japan: "Asia/Tokyo",
      korea: "Asia/Seoul",
      seoul: "Asia/Seoul",
      india: "Asia/Kolkata",
      delhi: "Asia/Kolkata",
      "new delhi": "Asia/Kolkata",
      mumbai: "Asia/Kolkata",
      bangalore: "Asia/Kolkata",
      bengaluru: "Asia/Kolkata",
      chennai: "Asia/Kolkata",
      hyderabad: "Asia/Kolkata",
      pune: "Asia/Kolkata",
      dubai: "Asia/Dubai",
      uae: "Asia/Dubai",
      "cape town": "Africa/Johannesburg",
      durban: "Africa/Johannesburg",
      "south africa": "Africa/Johannesburg",
      germany: "Europe/Berlin",
      france: "Europe/Paris",
      spain: "Europe/Madrid",
      italy: "Europe/Rome",
      milan: "Europe/Rome",
      barcelona: "Europe/Madrid",
      munich: "Europe/Berlin",
      frankfurt: "Europe/Berlin",
      manchester: "Europe/London",
      edinburgh: "Europe/London",
      melbourne: "Australia/Melbourne",
      canberra: "Australia/Sydney"
    })

  FileView {
    path: "/etc/zoneinfo/tzdata.zi"
    blockLoading: false

    onLoaded: {
      var out = {};
      var lines = text().split("\n");
      for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split(" ");
        // "Z Area/City ..." names a zone; "L Target Area/City" links one to it.
        var zone = f[0] === "Z" ? f[1] : f[0] === "L" ? f[1] : "";
        var name = f[0] === "Z" ? f[1] : f[0] === "L" ? f[2] : "";
        if (!zone || !name)
          continue;
        var city = name.split("/").pop().replace(/_/g, " ").toLowerCase();
        // A zone of its own beats a link, so "kolkata" is not shadowed by an alias.
        if (!out[city] || f[0] === "Z")
          out[city] = zone;
        out[name.toLowerCase()] = zone;
      }
      root.zones = out;
      root.compute();
    }
  }

  // The system zone by name, read off the /etc/localtime link.
  property string localZone: ""

  onLocalZoneChanged: compute()

  Process {
    command: ["readlink", "-f", "/etc/localtime"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        var m = text.trim().match(/zoneinfo\/(.+)$/);
        if (m)
          root.localZone = m[1];
      }
    }
  }

  function zoneFor(place) {
    var p = place.trim().toLowerCase().replace(/\s+/g, " ");
    if (p === "here" || p === "local")
      return "local";
    return root.zoneAliases[p] || root.zones[p] || "";
  }

  function placeName(place, zone) {
    var p = place.trim();
    if (zone === "local")
      return "Local time";
    if (p.length <= 4)
      return zone.split("/").pop().replace(/_/g, " ");
    return p.replace(/\b\w/g, function (ch) {
      return ch.toUpperCase();
    });
  }

  // "3pm", "15:30", "9:15 am", "noon"; returns the time GNU date reads, or "".
  function clockTime(s) {
    s = s.trim().toLowerCase();
    if (s === "noon")
      return "12:00";
    if (s === "midnight")
      return "00:00";
    var m = s.match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/);
    if (!m || (!m[2] && !m[3]))
      return "";
    var h = parseInt(m[1], 10);
    if (m[3]) {
      if (h < 1 || h > 12)
        return "";
      h = (h % 12) + (m[3] === "pm" ? 12 : 0);
    } else if (h > 23) {
      return "";
    }
    return ("0" + h).slice(-2) + ":" + (m[2] || "00");
  }

  readonly property string clockFormat: "+%H:%M\t%a %-d %b\t%Z\t%:z"

  // Works out which date call answers the query, or null when it is not a date question.
  function dateCommand(q) {
    var s = q.toLowerCase().replace(/\s+/g, " ");
    var m, zone, from, at, place;

    if (s === "now" || s === "time") {
      return {
        kind: "clock",
        label: "Local time",
        args: [root.clockFormat]
      };
    }

    m = s.match(/^(?:time|now|what time is it|current time) (?:in|at) (.+)$/) || s.match(/^(.+) time$/);
    if (m && (zone = zoneFor(m[1]))) {
      return {
        kind: "clock",
        label: placeName(m[1], zone),
        args: [root.clockFormat],
        zone: zone === "local" ? "" : zone
      };
    }

    // "3pm pst to london", "15:00 in tokyo", "9am tokyo to here".
    m = s.match(/^(.+?) (?:in|to|as) (.+)$/);
    if (m && (zone = zoneFor(m[2]))) {
      var left = m[1];
      at = clockTime(left);
      from = "";
      if (!at) {
        var split = left.match(/^(.+?) ([a-z][a-z ]*)$/);
        if (split && (at = clockTime(split[1])))
          from = zoneFor(split[2]);
        if (!at || !from)
          return null;
      }
      // date reads -d in the target's TZ, so a time with no zone of its own is pinned to
      // the local one explicitly.
      if (!from || from === "local")
        from = root.localZone;
      var when = (from ? 'TZ="' + from + '" ' : "") + at;
      return {
        kind: "clock",
        label: placeName(m[2], zone),
        zone: zone === "local" ? "" : zone,
        args: ["-d", when, root.clockFormat]
      };
    }

    // "days until 25 dec", "weeks since 2026-01-01".
    m = s.match(/^(days?|weeks?) (until|till|til|to|since|from) (.+)$/);
    if (m) {
      return {
        kind: m[1].startsWith("w") ? "weeks" : "days",
        label: m[2] === "since" || m[2] === "from" ? "since" : "until",
        args: ["-d", m[3], "+%s\t%a %-d %b %Y"]
      };
    }

    return null;
  }

  property string dateFor: ""
  property string dateRanFor: ""
  property string dateKind: ""
  property string dateLabel: ""
  // The zone the answer is printed in; empty is the shell's own.
  property string dateZone: ""
  property var dateArgs: []

  function dateRows(out) {
    var f = out.trim().split("\t");
    if (root.dateKind === "clock" && f.length === 4) {
      var offset = f[3] === "+00:00" ? "UTC" : "UTC" + f[3];
      return [row("clock", f[0], root.dateLabel + " · " + f[1] + " · " + f[2] + " (" + offset + ")", {
          glyph: Icons.clock
        })];
    }
    if (f.length === 2) {
      var today = new Date();
      today.setHours(0, 0, 0, 0);
      var target = new Date(parseInt(f[0], 10) * 1000);
      target.setHours(0, 0, 0, 0);
      var days = Math.round((target - today) / 86400000);
      if (root.dateLabel === "since")
        days = -days;
      var weeks = root.dateKind === "weeks";
      var n = weeks ? fixed(days / 7, 1) : String(days);
      var unit = weeks ? (n === "1" ? " week" : " weeks") : (days === 1 ? " day" : " days");
      return [row("days", n + unit, root.dateLabel.charAt(0).toUpperCase() + root.dateLabel.substr(1) + " " + f[1], {
          copy: n,
          glyph: Icons.calendar
        })];
    }
    return [];
  }

  QueuedProcess {
    id: date

    command: ["date"].concat(root.dateArgs)
    // The shell's own environment has no TZDIR, and glibc then cannot find any zone.
    environment: root.dateZone ? {
      TZDIR: "/etc/zoneinfo",
      TZ: root.dateZone
    } : {
      TZDIR: "/etc/zoneinfo"
    }

    onRunningChanged: {
      if (running)
        root.dateRanFor = root.dateFor;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.dateRanFor === root.dateFor && root.dateFor !== "")
          root.results = root.dateRows(text);
      }
    }

    onExited: function (code) {
      if (code !== 0 && root.dateRanFor === root.dateFor)
        root.results = [];
    }
  }

  // --- qalc -------------------------------------------------------------------------------

  // Raycast's spellings qalc reads differently: "10c to f" is coulombs to farads there,
  // and "20% of 150" is not an expression at all.
  function forQalc(q) {
    var t = q.replace(/^(-?[\d.]+)\s*°?([cfk])\s+(to|in)\s+°?([cfk])$/i, function (_, n, a, _2, b) {
      var unit = function (u) {
        u = u.toLowerCase();
        return u === "k" ? "K" : "°" + u.toUpperCase();
      };
      return n + " " + unit(a) + " to " + unit(b);
    });
    return t.replace(/(\d)\s*%\s+of\s+/gi, "$1% * ");
  }

  // Currencies come back to eight places; money reads to two, grouped.
  function tidy(result) {
    var m = result.match(/^([£$€¥₹₩₽₺₪฿₫₴₦]?)(-?\d+)\.(\d+)(\s*[A-Z]{3})?$/);
    if (m && (m[1] || m[4])) {
      var n = parseFloat(m[2] + "." + m[3]);
      var s = Math.abs(n).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
      return (n < 0 ? "-" : "") + m[1] + s + (m[4] || "");
    }
    return result.replace(/^"(.*)"$/, "$1");
  }

  property string qalcFor: ""
  property string qalcRanFor: ""

  // qalc prints "<expression as read> = <result>" (or ≈); errors and warnings are lines
  // of their own. An error means qalc guessed at the input, so nothing is shown.
  function qalcRows(out) {
    var lines = out.split("\n").filter(function (l) {
      return l.trim().length > 0;
    });
    var last = "";
    for (var i = 0; i < lines.length; i++) {
      if (/^error:/.test(lines[i]))
        return [];
      if (!/^warning:/.test(lines[i]))
        last = lines[i].trim();
    }
    if (!last)
      return [];

    var cut = Math.max(last.lastIndexOf(" = "), last.lastIndexOf(" ≈ "));
    var shown = cut >= 0 ? last.substr(0, cut) : root.qalcRanFor;
    var result = cut >= 0 ? last.substr(cut + 3) : last;
    var approx = cut >= 0 && last.substr(cut, 3) === " ≈ ";
    var value = tidy(result);
    if (!value || value === shown)
      return [];
    return [row("qalc", value, (approx ? "≈ " : "= ") + shown, {
        glyph: Icons.calculator
      })];
  }

  Process {
    command: ["sh", "-c", 'mkdir -p "$1/qalculate" && printf "%s" "$2" > "$1/qalculate/qalc.cfg"', "sh", root.qalcHome, root.qalcConfig]
    running: true
  }

  QueuedProcess {
    id: qalc

    // A 1 s ceiling keeps "99999!" from wedging the launcher.
    command: ["qalc", "-m", "1000", root.forQalc(root.qalcFor)]
    environment: ({
        XDG_CONFIG_HOME: root.qalcHome
      })

    onRunningChanged: {
      if (running)
        root.qalcRanFor = root.qalcFor;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.qalcRanFor === root.qalcFor && root.qalcFor !== "")
          root.results = root.qalcRows(text);
      }
    }

    stderr: StdioCollector {}
  }

  // Exchange rates live in qalc's shared data dir; refresh them in the background when
  // they are over half a day old, so a query never waits on the network.
  function refreshRates() {
    rates.run();
  }

  QueuedProcess {
    id: rates

    command: ["sh", "-c", 'f="${XDG_DATA_HOME:-$HOME/.local/share}/qalculate/eurofxref-daily.xml"; [ -n "$(find "$f" -mmin -720 2>/dev/null)" ] || exec qalc -e -t 0 >/dev/null']
  }

  Timer {
    interval: 6 * 60 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshRates()
  }
}
