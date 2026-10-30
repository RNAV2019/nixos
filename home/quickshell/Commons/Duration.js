.pragma library

// Durations as people type and read them, for the timer and the Pomodoro: "90s", "10m",
// "1h30m", "1h30", a bare "25" (minutes), "5:00" (m:ss) or "1:30:00" (h:mm:ss). All in milliseconds.

var UNIT = /^\s*(?:(\d+(?:\.\d+)?)\s*h(?:ours?|rs?)?)?\s*(?:(\d+(?:\.\d+)?)\s*m(?:in(?:ute)?s?)?)?\s*(?:(\d+(?:\.\d+)?)\s*s(?:ec(?:ond)?s?)?)?\s*$/i;

// 0 for anything that is not a positive duration.
function parse(spec) {
  var text = String(spec).trim();
  if (text === "")
    return 0;
  if (/^\d+(\.\d+)?$/.test(text))
    return Math.round(parseFloat(text) * 60000);
  if (/^\d+:\d{1,2}(:\d{1,2})?$/.test(text)) {
    var parts = text.split(":").map(Number);
    var secs = parts.length === 3 ? parts[0] * 3600 + parts[1] * 60 + parts[2] : parts[0] * 60 + parts[1];
    return secs * 1000;
  }
  // "1h30" is an hour and a half: what trails an hour with no unit is minutes.
  var hm = /^(\d+)\s*h(?:ours?|rs?)?\s*(\d+)$/i.exec(text);
  if (hm)
    return (parseInt(hm[1], 10) * 3600 + parseInt(hm[2], 10) * 60) * 1000;
  var m = UNIT.exec(text);
  if (!m || (m[1] === undefined && m[2] === undefined && m[3] === undefined))
    return 0;
  var ms = (parseFloat(m[1] || 0) * 3600 + parseFloat(m[2] || 0) * 60 + parseFloat(m[3] || 0)) * 1000;
  return Math.round(ms);
}

function pad(n) {
  return n < 10 ? "0" + n : String(n);
}

// The big readout: "6:12", "1:04:12". Rounds up, so it reads 0:01 until it is truly done.
function clock(ms) {
  var s = Math.max(0, Math.ceil(ms / 1000));
  var h = Math.floor(s / 3600);
  var m = Math.floor(s / 60) % 60;
  if (h > 0)
    return h + ":" + pad(m) + ":" + pad(s % 60);
  return Math.floor(s / 60) + ":" + pad(s % 60);
}

// What fits in a satellite: "6:12" under ten minutes, "12m" to 100, then "1h 40".
function short(ms) {
  var s = Math.max(0, Math.ceil(ms / 1000));
  if (s < 600)
    return clock(ms);
  var min = Math.floor(s / 60);
  if (min < 100)
    return min + "m";
  return Math.floor(min / 60) + "h " + (min % 60);
}

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
