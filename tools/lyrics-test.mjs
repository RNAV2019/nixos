#!/usr/bin/env node
// lyrics-test.mjs — how a lyrics service's answer is read (home/quickshell/Lyrics/Parse.js) and
// how the pill shows it (Lyrics/Pill.js), run under node on the harness's fixture song.
//
//   node tools/lyrics-test.mjs [LYRICS_DIR] [FIXTURE]    exits 1 if a check fails
//
// `nix flake check` runs it as checks.lyrics-logic.
import {readFileSync} from "node:fs";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dir = process.argv[2] || join(here, "../home/quickshell/Lyrics");
const fixture = process.argv[3] || join(here, "qs-verify/fixtures/lyrics-plus.json");
const load = (file, names) => new Function(readFileSync(join(dir, file), "utf8").replace(/^\.pragma library\s*$/m, "") + `\nreturn {${names}};`)();

const Parse = load("Parse.js", "cleanTitle, cleanArtist, splitTitle, syllables, spreadWords, tierOf, fromLyricsPlus, fromLrclib, cacheKey, lineAt");
const Pill = load("Pill.js", "cuts, phrases, wideFor, latest, opening, faceAt, dotLit, dotBreath, dotsShown, fill, swell, settled, weight, arrived, left, swept, escaped, LEAD, EARLY, LATE, COUNT, TITLE_FOR");

let failed = 0;
function check(name, ok, detail) {
  if (ok)
    return;
  failed++;
  console.error(`FAIL ${name}${detail === undefined ? "" : ": " + JSON.stringify(detail)}`);
}
const eq = (name, got, want) => check(name, JSON.stringify(got) === JSON.stringify(want), {got, want});

// ---- names, as players give them ----
eq("title: video suffix", Parse.cleanTitle("Blinding Lights (Official Video)"), "Blinding Lights");
eq("title: feat", Parse.cleanTitle("Song Name (feat. Someone) [Lyrics]"), "Song Name");
eq("title: remaster", Parse.cleanTitle("Heroes - 2017 Remaster"), "Heroes");
eq("title: kept brackets", Parse.cleanTitle("Weird Fishes/Arpeggi"), "Weird Fishes/Arpeggi");
eq("artist: topic", Parse.cleanArtist("Mira Okafor - Topic"), "Mira Okafor");
eq("artist: first of several", Parse.cleanArtist("One, Two & Three"), "One");
eq("split: a tab's title", Parse.splitTitle("The Lanterns - Night Bus Home (Official Audio)", ""), {title: "Night Bus Home", artist: "The Lanterns"});
eq("split: a player's own", Parse.splitTitle("Night Bus Home", "The Lanterns"), {title: "Night Bus Home", artist: "The Lanterns"});
eq("split: a dash in a real title", Parse.splitTitle("Up - Down", "Someone"), {title: "Up - Down", artist: "Someone"});
eq("cache key", Parse.cacheKey("Glass Harbour", "Mira Okafor", 152.4), "mira-okafor-glass-harbour-152");
eq("syllables", ["a", "night", "window", "afterglow", "time"].map(Parse.syllables), [1, 1, 2, 3, 1]);

// ---- the word-timed answer ----
const model = Parse.fromLyricsPlus(readFileSync(fixture, "utf8"));
check("plus: parsed", model !== null);
eq("plus: word timed", model.wordTimed, true);
eq("plus: lines", model.lines.length, 25);
eq("plus: parts", model.parts.map(p => p.name + ":" + p.tier), ["Verse:mid", "PreChorus:mid", "Chorus:high", "Verse:mid", "Chorus:high", "Bridge:calm", "Chorus:high"]);
eq("plus: syllables joined", model.lines[6].words.map(w => w.text), ["Hold", "on", "to", "the", "afterglow"]);
eq("plus: first line starts", model.lines[0].t, 8);
check("plus: words in order", model.lines.every(l => l.words.every((w, i) => i === 0 || w.t >= l.words[i - 1].t)));
check("plus: words inside their line", model.lines.every(l => l.words[0].t >= l.t - 0.001 && l.end <= l.out + 0.001));
check("plus: a line leaves when the next starts", Math.abs(model.lines[0].out - model.lines[1].t) < 0.001, model.lines[0]);
check("plus: the last line before a pause is held, then goes", Math.abs(model.lines[9].out - (model.lines[9].end + 1.4)) < 0.001, model.lines[9]);
eq("plus: a line's part", model.lines[8].part, 2);
eq("plus: not json", Parse.fromLyricsPlus("<html>"), null);
eq("plus: no lyrics", Parse.fromLyricsPlus('{"type":"None","lyrics":[]}'), null);
eq("lineAt: before", Parse.lineAt(model.lines, 2, 0.3), -1);
eq("lineAt: led", Parse.lineAt(model.lines, 7.8, 0.3), 0);
eq("lineAt: middle", Parse.lineAt(model.lines, 40, 0.3), 6);
eq("lineAt: after", Parse.lineAt(model.lines, 500, 0.3), 24);

// ---- the line-timed fallback ----
const lrc = Parse.fromLrclib(JSON.stringify({
  syncedLyrics: "[00:10.00] One two three\n[00:14.00]\n[00:20.50] Four five\n[00:24.00] One two three\n[00:28.00] One two three\n[00:40.00] Six",
}));
check("lrc: parsed", lrc !== null);
eq("lrc: not word timed", lrc.wordTimed, false);
eq("lrc: blank lines dropped", lrc.lines.map(l => l.text), ["One two three", "Four five", "One two three", "One two three", "Six"]);
check("lrc: words spread inside the line", lrc.lines[0].words.length === 3 && lrc.lines[0].end <= 14 && lrc.lines[0].words[2].t > 10.2, lrc.lines[0]);
eq("lrc: a thrice-sung line is the chorus", lrc.lines.map(l => lrc.parts[l.part].tier), ["high", "mid", "high", "high", "mid"]);
eq("lrc: nothing synced", Parse.fromLrclib('{"plainLyrics":"la la","syncedLyrics":null}'), null);

// ---- the pill: lines cut to its width ----
// Every letter 8 px, a space 4.
const measure = text => text.length * 8;
const widths = texts => texts.map(measure);
eq("cuts: a line that fits is one stretch", Pill.cuts(["a", "bb"], [8, 16], 4, 100), [[0, 2]]);
{
  const texts = "one two three four five six".split(" ");
  const parts = Pill.cuts(texts, widths(texts), 4, 100);
  eq("cuts: the fewest stretches that fit, evenly", parts, [[0, 3], [3, 6]]);
  const plain = "aa bbbb cccc dddd eeee".split(" ");
  const comma = "aa bbbb, cccc dddd eeee".split(" ");
  eq("cuts: an even cut where the line says nothing", Pill.cuts(plain, widths(plain), 4, 120), [[0, 3], [3, 5]]);
  eq("cuts: a comma is where a line would rather break", Pill.cuts(comma, widths(comma), 4, 120), [[0, 2], [2, 5]]);
  const long = ["supercalifragilistic", "is", "long"];
  check("cuts: a word wider than the pill stands alone", Pill.cuts(long, widths(long), 4, 100).some(p => p[0] === 0 && p[1] === 1), Pill.cuts(long, widths(long), 4, 100));
  check("cuts: every word once, in order", JSON.stringify(parts.flat()) === JSON.stringify([0, 3, 3, 6]));
}

// ---- the pill: when each phrase comes and goes ----
const whole = Pill.phrases(model.lines, measure, 1000);
eq("phrases: a wide pill takes whole lines", whole.length, model.lines.length);
eq("phrases: a line's width is its words and the spaces between", whole[6].width, measure("Hold") + measure("on") + measure("to") + measure("the") + measure("afterglow") + 4 * 8);
check("phrases: the first comes from the plain pill, a lead before its first word", whole[0].fromRest && Math.abs(whole[0].start - (8 - Pill.LEAD)) < 1e-9, whole[0]);
check("phrases: one that follows another does not come from the plain pill", !whole[1].fromRest && !whole[0].toRest);
check("phrases: a phrase leaves as the next comes up", whole.every((p, i) => p.toRest || p.stop === whole[i + 1].start));
check("phrases: none comes up before the one in front is sung", whole.every((p, i) => i === 0 || p.fromRest || p.start >= Math.min(whole[i - 1].end, p.t) - 1e-9));
check("phrases: the line before a pause goes back to the plain pill, held first", whole[9].toRest && Math.abs(whole[9].stop - model.lines[9].out) < 1e-9 && whole[10].fromRest, whole[9]);
const narrow = Pill.phrases(model.lines, measure, 150);
check("phrases: a narrow pill cuts lines up", narrow.length > model.lines.length && narrow.every(p => p.width <= 150 || p.words.length === 1), narrow.map(p => p.width));
check("phrases: a cut line's stretches follow one another without the plain pill between", narrow.every((p, i) => i === 0 || p.line !== narrow[i - 1].line || (!p.fromRest && !narrow[i - 1].toRest)));
check("phrases: and keep every word, in order", narrow.flatMap(p => p.words.map(w => w.text)).join(" ") === model.lines.map(l => l.text).join(" "));
eq("phrases: no lines, no phrases", Pill.phrases([], measure, 100), []);

eq("wideFor: before the song's first words", Pill.wideFor(whole, 5), -1);
eq("wideFor: the shape leads a phrase out of the plain pill", [Pill.wideFor(whole, 8 - Pill.LEAD - Pill.EARLY + 0.01), Pill.latest(whole, 8 - Pill.LEAD - Pill.EARLY + 0.01)], [0, -1]);
eq("wideFor: mid song", Pill.wideFor(whole, 38.6), 6);
eq("wideFor: held a moment after a line nothing follows", [Pill.wideFor(whole, whole[9].stop + Pill.LATE - 0.01), Pill.wideFor(whole, whole[9].stop + Pill.LATE + 0.01)], [9, -1]);
eq("wideFor: the pause between verses", Pill.wideFor(whole, 60), -1);
eq("latest: the last to come up", [Pill.latest(whole, 5), Pill.latest(whole, 38.6), Pill.latest(whole, 60)], [-1, 6, 9]);

// ---- the pill: while nobody sings ----
const titled = Pill.opening(whole);
check("opening: the song is named from its start until the first line's room is made", titled !== null && titled.start < 0.5 && Math.abs(titled.stop - (whole[0].start - Pill.EARLY)) < 1e-9, titled);
{
  const late = whole.map(p => ({...p, start: p.start + 20, stop: p.stop + 20, t: p.t + 20}));
  eq("opening: a long intro is named for a while, then counted in", Pill.opening(late).stop, Pill.TITLE_FOR);
  const soon = whole.map(p => ({...p, start: p.start - 7, stop: p.stop - 7, t: p.t - 7}));
  eq("opening: a song that sings at once is not named", Pill.opening(soon), null);
  eq("opening: no lines", Pill.opening([]), null);
  eq("faceAt: after the title, the dots", [Pill.faceAt(late, 3, Pill.opening(late)).kind, Pill.faceAt(late, 10, Pill.opening(late)).kind, Pill.faceAt(late, 10, Pill.opening(late)).from], ["title", "dots", Pill.TITLE_FOR]);
  eq("faceAt: an intro not named is counted in from the start", [Pill.faceAt(soon, 0.2, null).kind, Pill.faceAt(soon, 0.2, null).from], ["dots", 0]);
}
eq("faceAt: the title, then the first line", [Pill.faceAt(whole, 3, titled).kind, Pill.faceAt(whole, 9, titled).kind, Pill.faceAt(whole, 9, titled).index], ["title", "line", 0]);
eq("faceAt: agrees with wideFor wherever a line is up", [9, 13, 38.6, 55, 70, 120].map(t => Pill.faceAt(whole, t, titled).index), [9, 13, 38.6, 55, 70, 120].map(t => Pill.wideFor(whole, t)));
{
  const gap = Pill.faceAt(whole, 60, titled);
  eq("faceAt: the pause between verses is the dots, for the line to come", [gap.kind, gap.index], ["dots", 10]);
  check("faceAt: the dots stand from when the last line has gone until the next one's room is made", Math.abs(gap.from - (whole[9].stop + Pill.LATE)) < 1e-9 && Math.abs(gap.until - (whole[10].start - Pill.EARLY)) < 1e-9, gap);
  check("faceAt: the count ends as the line comes up, and is never longer than the pause", Math.abs(gap.countUntil - whole[10].start) < 1e-9 && gap.countFrom >= gap.from && gap.countUntil - gap.countFrom <= Pill.COUNT + 1e-9, gap);
  eq("dots: unlit before the count, lit in turn, all lit at its end", [Pill.dotLit(gap, 0, gap.countFrom), Pill.dotLit(gap, 2, gap.countFrom), Pill.dotLit(gap, 0, gap.countUntil), Pill.dotLit(gap, 2, gap.countUntil)], [0, 0, 1, 1]);
  const mid = (gap.countFrom + gap.countUntil) / 2;
  check("dots: the first is lit before the second, the second before the third", Pill.dotLit(gap, 0, mid) === 1 && Pill.dotLit(gap, 1, mid) > 0 && Pill.dotLit(gap, 1, mid) < 1 && Pill.dotLit(gap, 2, mid) === 0);
  check("dots: come in after the line has gone and are gone as the next one's room is made", Pill.dotsShown(gap, gap.from) === 0 && Pill.dotsShown(gap, (gap.from + gap.until) / 2) === 1 && Pill.dotsShown(gap, gap.until) === 0);
  check("dots: breathe only while they wait", Pill.dotBreath(gap, 0, gap.countUntil - 0.1) === 0 && Array.from({length: 50}, (_, i) => Pill.dotBreath({...gap, countFrom: 1e9}, 1, gap.from + i / 10)).every(x => x >= 0 && x <= 1));
}
eq("faceAt: after the last line, the plain pill", Pill.faceAt(whole, 145, titled).kind, "plain");
eq("faceAt: no lines, the plain pill", Pill.faceAt([], 3, null).kind, "plain");

// ---- the pill: a word at a moment ----
const word = {t: 10, d: 1, text: "afterglow"};
eq("fill: before, half way, after", [Pill.fill(word, 9), Pill.fill(word, 10.5), Pill.fill(word, 12)], [0, 0.5, 1]);
check("swell: at rest before, up while sung, down again after", Pill.swell(word, 9.9) === 0 && Pill.swell(word, 10.6) === 1 && Pill.swell(word, 12) === 0 && Pill.swell(word, 11.2) > 0 && Pill.swell(word, 11.2) < 1);
check("swell: never past one, never below nought", Array.from({length: 400}, (_, i) => Pill.swell(word, 9.5 + i / 100)).every(x => x >= 0 && x <= 1));
eq("settled: only once sung", [Pill.settled(word, 10.9), Pill.settled(word, 13)], [0, 1]);
eq("weight: by how long it is held", [Pill.weight({d: 0.2}), Pill.weight({d: 1}), Pill.weight({d: 3})], [0, 0.5, 1]);
check("arrived: each word a little after the one before", Pill.arrived(whole[0], 0, whole[0].start) === 0 && Pill.arrived(whole[0], 0, whole[0].start + 0.1) > Pill.arrived(whole[0], 3, whole[0].start + 0.1) && Pill.arrived(whole[0], 5, whole[0].start + 1) === 1);
eq("left: not before its stop, gone a fifth of a second after", [Pill.left(whole[0], whole[0].stop - 0.1), Pill.left(whole[0], whole[0].stop + 0.3), Pill.left(null, 0)], [0, 1, 1]);
eq("swept: unsung", Pill.swept("ab", 0, "ffffff", 0.2, 1), '<font color="#33ffffff">ab</font>');
eq("swept: sung", Pill.swept("ab", 1, "ffffff", 0.2, 1), '<font color="#ffffffff">ab</font>');
{
  const mid = Pill.swept("afterglow", 0.5, "e6e4de", 0.34, 1);
  const tones = [...mid.matchAll(/#([0-9a-f]{2})e6e4de/g)].map(m => parseInt(m[1], 16));
  check("swept: lit at the front, unlit at the back, never brighter further on", tones[0] === 255 && tones[tones.length - 1] === Math.round(0.34 * 255) && tones.every((t, i) => i === 0 || t <= tones[i - 1]), tones);
  eq("swept: the letters are all there", mid.replace(/<[^>]+>/g, ""), "afterglow");
}
eq("swept: what a tag would mind is escaped", Pill.swept("<&>", 0, "000000", 1, 1), '<font color="#ff000000">&lt;&amp;&gt;</font>');

if (failed > 0) {
  console.error(`${failed} failed`);
  process.exit(1);
}
console.log("lyrics logic: ok");
