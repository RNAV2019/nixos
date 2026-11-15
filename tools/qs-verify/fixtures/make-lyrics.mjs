// Writes fixtures/lyrics-plus.json: a song in the shape LyricsPlus answers with (v2, word-timed,
// with named parts), for the mock player's first track ("Glass Harbour", 2:32). The words are
// written for the harness and the timings are made up: 100 beats a minute, a line every two
// bars, each word's length by its syllables and the last word of a line held.
//   node tools/qs-verify/fixtures/make-lyrics.mjs > tools/qs-verify/fixtures/lyrics-plus.json
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
const ms = s => Math.round(s * 1000);

const lyrics = [];
const songParts = [];
let key = 0;
SONG.forEach(([name, start, lines], part) => {
  songParts.push({ name, time: ms(start), duration: ms(lines.length * LINE), divIndex: part });
  lines.forEach((text, i) => {
    const t0 = start + i * LINE;
    const words = text.split(" ");
    // The line is sung over three and a half of its four seconds and a bit; the last word
    // takes a double share.
    const shares = words.map((w, k) => syllables(w) + (k === words.length - 1 ? 2 : 0));
    const total = shares.reduce((a, b) => a + b, 0);
    const span = LINE * 0.82;
    let at = t0;
    const syllabus = [];
    words.forEach((w, k) => {
      const d = span * shares[k] / total;
      const tail = k === words.length - 1 ? "" : " ";
      if (w.replace(/[^a-z]/gi, "").length > 7) {
        // A long word comes as two syllables, as the service sends them.
        const cut = Math.ceil(w.length / 2);
        syllabus.push({ time: ms(at), duration: ms(d / 2), text: w.slice(0, cut) });
        syllabus.push({ time: ms(at + d / 2), duration: ms(d / 2), text: w.slice(cut) + tail });
      } else {
        syllabus.push({ time: ms(at), duration: ms(d), text: w + tail });
      }
      at += d;
    });
    lyrics.push({
      time: ms(t0),
      duration: ms(span),
      text,
      element: { key: "L" + ++key, singer: "v1", songPartIndex: part },
      syllabus,
    });
  });
});

console.log(JSON.stringify({
  type: "Word",
  metadata: { source: "Apple", songWriters: ["qs-verify"], songParts },
  lyrics,
}, null, 1));
