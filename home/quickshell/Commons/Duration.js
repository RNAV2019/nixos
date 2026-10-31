.pragma library

// A length in words: "10 min", "1 h 30 min", "90 s", "2 min 30 s".
function describe(ms) {
  var s = Math.round(ms / 1000);
  var h = Math.floor(s / 3600);
  var m = Math.floor(s / 60) % 60;
  var r = s % 60;
  var parts = [];
  if (h > 0)
    parts.push(h + " h");
  if (m > 0)
    parts.push(m + " min");
  if (r > 0 || parts.length === 0)
    parts.push(r + " s");
  return parts.join(" ");
}

// How long something has run, as a clock: "1:58", "1:04:12". Whole seconds, rounded down.
function elapsed(ms) {
  var s = Math.max(0, Math.floor(ms / 1000));
  var h = Math.floor(s / 3600);
  var m = Math.floor(s / 60) % 60;
  var r = s % 60;
  var pad = function (n) {
    return n < 10 ? "0" + n : String(n);
  };
  return h > 0 ? h + ":" + pad(m) + ":" + pad(r) : Math.floor(s / 60) + ":" + pad(r);
}
