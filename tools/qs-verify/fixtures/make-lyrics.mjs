// Writes the lyrics fixtures: a song as the two sources the shell asks answer for it, for the
// mock player's first track ("Glass Harbour" by Mira Okafor, on "Tidewater", 2:32). The words are
// written for the harness and the timings are made up: 100 beats a minute, a line every two
// bars, each word's length by its syllables and the last word of a line held.
//   node tools/qs-verify/fixtures/make-lyrics.mjs tools/qs-verify/fixtures
// writes into the directory it is given:
//   lyrics-apple.json    the Apple Music catalogue's search answer: the recording, and a live
//                        take of it, each with where its sheet is
//   lyrics-apple.ttml    the recording's sheet, timed word by word, a long word in two syllables
//                        and one line with a backing voice after it
//   lyrics-lrclib.json   LRCLIB's search answer: an upload timed word by word and cut into lines
//                        its own way, one timed line by line and cut as the song is sung, one of
//                        another recording (a different length), and one with plain words only
import {writeFileSync} from "node:fs";
import {join} from "node:path";
const BEAT = 0.6;
const LINE = 8 * BEAT;
const SONG = [
  ["Verse", 8.0, [
    "Streetlights hum a low gold tune",
    "I take the long way round the moon",
    "Every window holds a little sky",
    "and I'm just passing by",
  ]],
  ["PreChorus", 27.2, [
    "Slow down, the night is wide",
    "there's nowhere left to hide",
  ]],
  ["Chorus", 36.8, [
    "Hold on to the afterglow",
    "let the fire burn slow",
    "my heart is an open road",
    "don't let go, don't let go",
  ]],
  ["Verse", 64.0, [
    "Paper boats on a silver sea",
    "carry what is left of me",
    "The radio plays a song we knew",
    "and the rain falls blue",
  ]],
  ["Chorus", 83.2, [
    "Hold on to the afterglow",
    "let the fire burn slow",
    "my heart is an open road",
    "don't let go, don't let go",
  ]],
  ["Bridge", 102.4, [
    "If the stars forget our names",
    "we will dance in the dark again",
    "one more time, one more time",
  ]],
  ["Chorus", 116.8, [
    "Hold on to the afterglow",
    "let the fire burn slow",
    "my heart is an open road",
    "don't let go, don't let go",
  ]],
];

const syllables = w => Math.max(1, (w.toLowerCase().replace(/[^a-z]/g, "").match(/[aeiouy]+/g) || []).length);
const stamp = s => s.toFixed(3);
const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// Every line as { start, end, text, words: [{ start, end, text }] }, a long word as two pieces.
const lines = [];
const parts = [];
SONG.forEach(([name, start, texts]) => {
  const part = {name, lines: []};
  parts.push(part);
  texts.forEach((text, i) => {
    const t0 = start + i * LINE;
    const said = text.split(" ");
    // The line is sung over three and a half of its four seconds and a bit; the last word
    // takes a double share.
    const shares = said.map((w, k) => syllables(w) + (k === said.length - 1 ? 2 : 0));
    const total = shares.reduce((a, b) => a + b, 0);
    const span = LINE * 0.82;
    let at = t0;
    const words = [];
    said.forEach((w, k) => {
      const d = span * shares[k] / total;
      const tail = k === said.length - 1 ? "" : " ";
      if (w.replace(/[^a-z]/gi, "").length > 7) {
        const cut = Math.ceil(w.length / 2);
        words.push({start: at, end: at + d / 2, text: w.slice(0, cut)});
        words.push({start: at + d / 2, end: at + d, text: w.slice(cut) + tail});
      } else {
        words.push({start: at, end: at + d, text: w + tail});
      }
      at += d;
    });
    const line = {start: t0, end: t0 + span, text, words};
    lines.push(line);
    part.lines.push(line);
  });
});

// ---- Apple Music: the catalogue's answer, and the sheet ----
const apple = {
  results: [
    {track_name: "Glass Harbour (Live)", artist_name: "Mira Okafor", album_name: "Tidewater Live", duration: 171, id: "QSV000000002", isrc: "QSV000000002", lyricsUrl: "https://lrc.red/s/QSV000000002.ttml", timing_type: "word"},
    {track_name: "Glass Harbour", artist_name: "Mira Okafor", album_name: "Tidewater", duration: 152, id: "QSV000000001", isrc: "QSV000000001", lyricsUrl: "https://lrc.red/s/QSV000000001.ttml", timing_type: "word"},
  ],
  source: "HIT-LRC-RED",
  total: 2,
};

let key = 0;
const ttml = '<tt xmlns="http://www.w3.org/ns/ttml" xmlns:lrc="http://lrc.red/lyric-ttml-internal" xmlns:ttm="http://www.w3.org/ns/ttml#metadata" lrc:timing="Word" xml:lang="en">'
  + '<head><metadata><ttm:agent type="person" xml:id="v1"/><sourceMetadata xmlns="http://lrc.red/lyric-ttml-internal"><songwriters><songwriter>qs-verify</songwriter></songwriters></sourceMetadata></metadata></head>'
  + '<body dur="2:32.000">'
  + parts.map(part => {
    const first = part.lines[0], last = part.lines[part.lines.length - 1];
    return `<div begin="${stamp(first.start)}" end="${stamp(last.end)}" lrc:songPart="${part.name}">` + part.lines.map(line => {
      // The last line of the bridge has a voice behind it, sung once its own words are over.
      const echo = line.text === "one more time, one more time"
        ? ` <span ttm:role="x-bg"><span begin="${stamp(line.end + 0.15)}" end="${stamp(line.end + 0.45)}">one</span> <span begin="${stamp(line.end + 0.45)}" end="${stamp(line.end + 0.75)}">more</span></span>`
        : "";
      const spans = line.words.map(w => `<span begin="${stamp(w.start)}" end="${stamp(w.end)}">${esc(w.text.trimEnd())}</span>${w.text.endsWith(" ") ? " " : ""}`).join("");
      return `<p begin="${stamp(line.start)}" end="${stamp(echo ? line.end + 0.75 : line.end)}" lrc:key="L${++key}" ttm:agent="v1">${spans}${echo}</p>`;
    }).join("") + "</div>";
  }).join("")
  + "</body></tt>\n";

// ---- LRCLIB: its uploads ----
const quote = t => /^[A-Za-z][A-Za-z ]*[A-Za-z]$/.test(t) ? t : "'" + t.replace(/'/g, "''") + "'";
// The word-timed upload runs each pair of lines together, as a timing tool's export may, and
// is 60 ms late throughout: the shell sets its words on the line-timed upload's lines.
const LATE = 0.06;
const pairs = [];
for (let i = 0; i < lines.length; i += 2)
  pairs.push(lines.slice(i, i + 2));
const whole = w => {
  // Syllables back into words, as this source times whole words.
  const out = [];
  w.forEach(piece => {
    const open = out[out.length - 1];
    if (open && !open.text.endsWith(" "))
      Object.assign(open, {end: piece.end, text: open.text + piece.text});
    else
      out.push({...piece});
  });
  return out;
};
const wordFile = "version: '1.0'\nmetadata:\n  title: Glass Harbour\n  artist: Mira Okafor\n  album: Tidewater\n  duration_ms: 152000\n  instrumental: false\n  language: en\nlines:\n"
  + pairs.map(pair => {
    const words = pair.flatMap((line, k) => whole(line.words).map((w, n, all) => ({...w, text: n === all.length - 1 && k === 0 && pair.length > 1 ? w.text + " " : w.text})));
    return `- text: ${quote(pair.map(l => l.text).join(" "))}\n  start_ms: ${Math.round((pair[0].start + LATE) * 1000)}\n  end_ms: ${Math.round((pair[pair.length - 1].end + LATE) * 1000)}\n  words:\n`
      + words.map(w => `  - text: ${quote(w.text)}\n    start_ms: ${Math.round((w.start + LATE) * 1000)}\n`).join("");
  }).join("")
  + "plain: |-\n" + lines.map(l => "  " + l.text + "\n").join("");
const tag = s => `[${String(Math.floor(s / 60)).padStart(2, "0")}:${(s % 60).toFixed(2).padStart(5, "0")}]`;
// The line-timed upload: a blank stamp where the singing stops, as its uploaders mark a pause.
const lrc = parts.map(part => part.lines.map(l => `${tag(l.start)} ${l.text}`).join("\n") + "\n" + tag(part.lines[part.lines.length - 1].end + 0.4)).join("\n");
const plain = lines.map(l => l.text).join("\n");
const upload = (id, more) => ({id, name: "Glass Harbour", trackName: "Glass Harbour", artistName: "Mira Okafor", albumName: "Tidewater", duration: 152, instrumental: false, hasWordSync: false, plainLyrics: plain, syncedLyrics: null, lyricsfile: null, ...more});
const lrclib = [
  upload(9001, {hasWordSync: true, syncedLyrics: pairs.map(p => `${tag(p[0].start + LATE)} ${p.map(l => l.text).join(" ")}`).join("\n"), lyricsfile: wordFile}),
  upload(9002, {duration: 152.4, syncedLyrics: lrc}),
  upload(9003, {albumName: "Tidewater Live", duration: 171, syncedLyrics: lines.map(l => `${tag(l.start + 9)} ${l.text}`).join("\n")}),
  upload(9004, {albumName: "null"}),
];

const out = process.argv[2] || ".";
writeFileSync(join(out, "lyrics-apple.json"), JSON.stringify(apple, null, 1) + "\n");
writeFileSync(join(out, "lyrics-apple.ttml"), ttml);
writeFileSync(join(out, "lyrics-lrclib.json"), JSON.stringify(lrclib, null, 1) + "\n");
