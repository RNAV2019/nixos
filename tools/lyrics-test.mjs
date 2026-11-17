#!/usr/bin/env node
// lyrics-test.mjs — how the lyrics sources' answers are read (home/quickshell/Lyrics/Sheets.js),
// which of them is taken for the song (Rank.js), the shape the pill draws from (Parse.js) and
// how it shows it (Pill.js), run under node on the harness's fixture song.
//
//   node tools/lyrics-test.mjs [LYRICS_DIR] [FIXTURES_DIR]    exits 1 if a check fails
//
// `nix flake check` runs it as checks.lyrics-logic.
import {readFileSync} from "node:fs";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dir = process.argv[2] || join(here, "../home/quickshell/Lyrics");
const fixtures = process.argv[3] || join(here, "qs-verify/fixtures");
const fixture = name => readFileSync(join(fixtures, name), "utf8");
const load = (file, names) => new Function(readFileSync(join(dir, file), "utf8").replace(/^\.pragma library\s*$/m, "") + `\nreturn {${names}};`)();

const Parse = load("Parse.js", "cleanTitle, cleanArtist, cleanArtists, splitTitle, syllables, spreadWords, wordsOf, fromSheet, cacheKey, lineAt");
const Sheets = load("Sheets.js", "structural, fromTtml, fromLrc, fromLyricsFile, lrclibHits, resolved, appleMatches, appleHit");
const Rank = load("Rank.js", "undecorated, alike, artistsAlike, matched, truncated, lowQuality, score, rank, conform, reshaped, best, fullySynced, pick");
const Clock = load("Clock.js", "parse, step");
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
eq("artists: all of several", Parse.cleanArtists("One, Two & Three - Topic"), "One, Two & Three");
eq("split: a tab's title", Parse.splitTitle("The Lanterns - Night Bus Home (Official Audio)", ""), {title: "Night Bus Home", artist: "The Lanterns", artists: "The Lanterns"});
eq("split: a player's own", Parse.splitTitle("Night Bus Home", "The Lanterns, Someone"), {title: "Night Bus Home", artist: "The Lanterns", artists: "The Lanterns, Someone"});
eq("split: a dash in a real title", Parse.splitTitle("Up - Down", "Someone"), {title: "Up - Down", artist: "Someone", artists: "Someone"});
eq("cache key", Parse.cacheKey("Glass Harbour", "Mira Okafor", 152.4), "mira-okafor-glass-harbour-152");
eq("syllables", ["a", "night", "window", "afterglow", "time"].map(Parse.syllables), [1, 1, 2, 3, 1]);

// ---- Apple Music: the catalogue's answer and its sheet ----
const QUERY = {title: "Glass Harbour", artist: "Mira Okafor", album: "Tidewater", duration: 152};
const ORDER = ["Apple Music", "LRCLIB"];
const near = (a, b) => Math.abs(a - b) < 0.0015;
const matches = Sheets.appleMatches(fixture("lyrics-apple.json"));
eq("apple: the recordings it knows", matches.map(m => m.title + ":" + m.duration + ":" + m.worded), ["Glass Harbour (Live):171:true", "Glass Harbour:152:true"]);
eq("apple: not json", Sheets.appleMatches("<html>"), null);
eq("apple: nothing found", Sheets.appleMatches('{"results":[],"total":0}'), []);
eq("apple: a sheet not on https is not asked for", Sheets.appleMatches('{"results":[{"track_name":"x","lyricsUrl":"http://a/b.ttml","timing_type":"word"}]}'), []);
eq("apple: word-timed recordings first", Sheets.appleMatches('{"results":[{"track_name":"a","lyricsUrl":"https://a/1","timing_type":"line"},{"track_name":"b","lyricsUrl":"https://a/2","timing_type":"syllable"}]}').map(m => m.title), ["b", "a"]);
eq("apple: the live take is another recording", matches.map(m => Rank.matched(QUERY, m)), [false, true]);
eq("apple: the recording that is playing is the one asked for", Rank.pick(QUERY, matches).url, "https://lrc.red/s/QSV000000001.ttml");
eq("apple: of two editions, the nearer in length", Rank.pick(QUERY, [{...matches[1], duration: 156, url: "a"}, {...matches[1], duration: 153, url: "b"}]).url, "b");
eq("apple: word-timed before a nearer line-timed", Rank.pick(QUERY, [{...matches[1], worded: false, url: "a"}, {...matches[1], duration: 154, url: "b"}]).url, "b");
eq("apple: none of them the song", Rank.pick({...QUERY, artist: "Somebody Else"}, matches), null);
const apple = Sheets.appleHit(matches[1], fixture("lyrics-apple.ttml"));
check("ttml: read", apple !== null && apple.source === "Apple Music" && apple.worded);
eq("ttml: lines, the backing voice one of its own", apple.lines.length, 26);
eq("ttml: a line's text", apple.lines[0].text, "Streetlights hum a low gold tune");
eq("ttml: syllables as pieces, a space ending a word", apple.lines[0].words.slice(0, 3).map(w => w.text), ["Street", "lights ", "hum "]);
check("ttml: stamps past a minute", near(apple.lines[10].start, 64) && near(apple.lines[10].words[0].start, 64), apple.lines[10]);
eq("ttml: the voice behind a line comes after it, in brackets", apple.lines.slice(20, 22).map(l => l.text), ["one more time, one more time", "(one more)"]);
check("ttml: and the line ends with its own words", near(apple.lines[20].end, 115.936) && near(apple.lines[21].start, 116.086), apple.lines[20]);
eq("ttml: a voice under the line is left out", Sheets.fromTtml('<tt><body><div><p begin="1.0" end="4.0"><span begin="1.0" end="2.0">One</span> <span begin="2.0" end="3.5">two</span><span ttm:role="x-bg"><span begin="1.5" end="2.5">ooh</span></span></p><p begin="5" end="6"><span begin="5" end="6">Three &amp; four</span><span ttm:role="x-translation">trois</span></p></div></body></tt>').map(l => l.text), ["One two", "Three & four"]);
eq("ttml: untimed", Sheets.fromTtml("<tt><body><div><p>One</p><p>Two</p></div></body></tt>"), []);
eq("ttml: not a sheet", Sheets.fromTtml("not found"), []);

// ---- LRC ----
{
  const lrc = Sheets.fromLrc("[offset:+500]\n[ar:Someone]\n[00:10.00] One two three\n[00:14.00]\n[00:20.50][00:30.50] Four five\n[00:24.00] [Chorus]\n[00:25.00] <00:25.00>Six <00:25.50>seven<00:26.20>\n[01:00,5] Eight [01:02.00]\n♪");
  eq("lrc: lines, blank and section lines dropped, a twice-stamped line twice", lrc.map(l => l.text), ["One two three", "Four five", "Six seven", "Four five", "Eight"]);
  check("lrc: an offset moves the sheet earlier", near(lrc[0].start, 9.5), lrc[0]);
  check("lrc: a blank stamp ends the line before it", near(lrc[0].end, 13.5), lrc[0]);
  eq("lrc: a line timed as a whole has no words", lrc[0].words, null);
  check("lrc: words between marks, the last ending at the closing mark", lrc[2].words.length === 2 && lrc[2].words[0].text === "Six " && near(lrc[2].words[0].end, 25) && near(lrc[2].words[1].end, 25.7), lrc[2].words);
  check("lrc: a stamp closing a line is its end", near(lrc[4].start, 60) && near(lrc[4].end, 61.5), lrc[4]);
  eq("lrc: nothing timed", Sheets.fromLrc("just words\nand more"), []);
  eq("section lines", ["[Chorus]", "- Verse -", "♪", "", "[Chorus] and on", "Chorus"].map(Sheets.structural), [true, true, true, true, false, false]);
}

// ---- LRCLIB: its uploads ----
const offered = Sheets.lrclibHits(fixture("lyrics-lrclib.json"));
eq("lrclib: uploads with times, the plain one left out", offered.map(h => h.duration + ":" + h.worded + ":" + h.lines.length), ["152:true:13", "152.4:false:25", "171:false:25"]);
check("lrclib: a word file is not read until it is wanted", typeof offered[0].file === "string" && offered[0].lines[0].words === null && offered[1].file === undefined);
const uploads = offered.map(Sheets.resolved);
check("lrclib: read, it is the hit's lines", uploads[0].file === undefined && uploads[0].worded && uploads[1] === offered[1]);
{
  const broken = Sheets.resolved({...offered[0], file: "lines:\n- text: a\n  what is this\n"});
  check("lrclib: a word file that cannot be read leaves the LRC's lines", !broken.worded && broken.lines.length === 13);
  const rows = JSON.parse(fixture("lyrics-lrclib.json"));
  delete rows[0].hasWordSync;
  rows[1].syncedLyrics = null;
  rows[1].lyricsfile = "lines:\n- text: only a file\n  start_ms: 1000\n  end_ms: 2000\n- text: and a second line\n  start_ms: 3000\n";
  const eager = Sheets.lrclibHits(JSON.stringify(rows));
  check("lrclib: a file with no word of what it times, or no LRC beside it, is read at once", eager[0].file === undefined && eager[0].worded && eager[1].lines.length === 2 && !eager[1].worded, eager.map(h => h.lines.length));
}
eq("lrclib: a word file's line", uploads[0].lines[0].text, "Streetlights hum a low gold tune I take the long way round the moon");
check("lrclib: its words, each ending where the next begins", uploads[0].lines[0].words[0].text === "Streetlights " && near(uploads[0].lines[0].words[0].start, 8.06), uploads[0].lines[0].words[0]);
eq("lrclib: only the uploads wanted are read", Sheets.lrclibHits(fixture("lyrics-lrclib.json"), h => Rank.matched(QUERY, h)).map(h => h.duration), [152, 152.4]);
eq("lrclib: not json", Sheets.lrclibHits("<html>"), null);
eq("lrclib: nothing found", Sheets.lrclibHits("[]"), []);
{
  const file = "version: \"1.0\"\nmetadata:\n  title: X\nlines:\n  - text: \"It's \\\"so\\\" far\"\n    start_ms: 1000\n    end_ms: 3000\n    words:\n      - text: 'It''s '\n        start_ms: 1000\n        end_ms: 1400\n      - text: '\"so\" '\n        start_ms: 1400\n      - text: far\n        start_ms: 2000\n  - text: a line folded\n      onto a second row\n    start_ms: 4000\nplain: |-\n  It's so far\n";
  const read = Sheets.fromLyricsFile(file);
  eq("word file: nested lists, quotes of both kinds, a folded text", read.map(l => l.text), ["It's \"so\" far", "a line folded onto a second row"]);
  eq("word file: its words", read[0].words.map(w => w.text + "@" + w.start), ["It's @1", "\"so\" @1.4", "far@2"]);
  check("word file: a word with no end lasts to the line's", near(read[0].words[2].end, 3), read[0].words);
  eq("word file: no lines in it", Sheets.fromLyricsFile("version: '1.0'\nlines: null\nplain: |-\n  la\n"), null);
  eq("word file: not that shape", Sheets.fromLyricsFile("lines:\n- text: a\n  start_ms: 1\n  what is this\n"), null);
}

// ---- which sheet is the song's ----
eq("names: undecorated", ["Jaded (Remastered 2024)", "Jaded - Single", "Don't Stop", "bôa"].map(Rank.undecorated), ["jaded", "jaded", "dontstop", "bôa"]);
eq("names: alike", [Rank.alike("Don't Stop", "dont stop"), Rank.alike("Jaded", "Rotoscope"), Rank.alike("Love", "Love Story (Taylor's Version)"), Rank.alike("Love Story", "Love Story (Taylor's Version)")], [true, false, false, true]);
eq("names: one shared artist is enough", [Rank.artistsAlike("Spiritbox, Megan Thee Stallion", "Spiritbox"), Rank.artistsAlike("Aerosmith", "Spiritbox")], [true, false]);
eq("matched: the recording, by its length", uploads.map(h => Rank.matched(QUERY, h)), [true, true, false]);
check("matched: any length when the player gives none", Rank.matched({...QUERY, duration: 0}, uploads[2]));
check("matched: not another artist's song of the name", !Rank.matched(QUERY, {...uploads[0], artist: "Somebody Else"}));
{
  const all = [apple].concat(uploads);
  eq("rank: Apple's sheet first, then the word-timed upload, then the line-timed; another recording never", Rank.rank(QUERY, all, ORDER).map(h => h.source + ":" + h.worded), ["Apple Music:true", "LRCLIB:true", "LRCLIB:false"]);
  eq("rank: the order of the sources decides before the score", Rank.rank(QUERY, all, ["LRCLIB", "Apple Music"])[0].source, "LRCLIB");
  eq("rank: twins are one", Rank.rank(QUERY, [uploads[1], {...uploads[1]}], ORDER).length, 1);
  const cut = {...uploads[1], lines: uploads[1].lines.slice(0, 8)};
  check("rank: a sheet that stops early is behind a whole one", Rank.truncated(cut, 152) && Rank.rank(QUERY, [cut, uploads[0]], ORDER)[0] === uploads[0]);
  eq("best: nothing but a sheet cut short is nothing", Rank.best(QUERY, [cut], ORDER), null);
  const early = {...apple, lines: apple.lines.slice(0, 8)};
  check("best: unless it is the recording's own sheet, of the song's own length", Rank.best(QUERY, [early], ORDER) === early && Rank.best(QUERY, [{...early, duration: 160}], ORDER) === null);
  check("best: and a whole upload is still before it", Rank.best(QUERY, [early, uploads[1]], ORDER).source === "LRCLIB");
  const shout = {...uploads[1], lines: uploads[1].lines.map((l, i) => i % 4 === 0 ? {...l, text: "AHHHHHH!!!"} : l)};
  check("rank: a sheet typed for effect is left out", Rank.lowQuality(shout) && Rank.rank(QUERY, [shout], ORDER).length === 0);
  eq("best: Apple's when it has the song", Rank.best(QUERY, all, ORDER).source, "Apple Music");

  // Without Apple's: the upload timed word by word, on the lines of the one timed by line.
  const recut = Rank.best(QUERY, offered, ORDER, Sheets.resolved);
  eq("best: the same whether the word file was read before or is read for it", JSON.stringify(recut), JSON.stringify(Rank.best(QUERY, uploads, ORDER)));
  eq("best: a word file that cannot be read gives way to the line-timed upload", Rank.best(QUERY, [{...offered[0], file: "lines: null\n"}, offered[1]], ORDER, Sheets.resolved).worded, false);
  check("reshape: the word-timed upload is taken", recut.source === "LRCLIB" && recut.worded);
  eq("reshape: on the line-timed upload's lines", recut.lines.map(l => l.text), uploads[1].lines.map(l => l.text));
  check("reshape: keeping its own times", near(recut.lines[0].words[0].start, 8.06) && near(recut.lines[1].start, 12.86), recut.lines.slice(0, 2).map(l => l.start));
  eq("reshape: every word once, cut from the guide's text", recut.lines[1].words.map(w => w.text), ["I ", "take ", "the ", "long ", "way ", "round ", "the ", "moon"]);
  eq("reshape: other words are left as they are", Rank.conform(uploads[0].lines, Sheets.fromLrc("[00:01.00] nothing like it at all here\n[00:05.00] not one of these words is sung")), null);
  check("reshape: Apple's sheet is never re-cut", Rank.reshaped(apple, [apple, uploads[1]]) === apple);
}

// ---- the shape the pill draws from ----
const model = Parse.fromSheet(apple);
check("model: made", model !== null);
eq("model: word timed", [model.source, model.wordTimed], ["Apple Music", true]);
eq("model: lines", model.lines.length, 26);
eq("model: syllables joined into words", model.lines[6].words.map(w => w.text), ["Hold", "on", "to", "the", "afterglow"]);
eq("model: first line starts", model.lines[0].t, 8);
check("model: words in order", model.lines.every(l => l.words.every((w, i) => i === 0 || w.t >= l.words[i - 1].t)));
check("model: words inside their line", model.lines.every(l => l.words[0].t >= l.t - 0.001 && l.end <= l.out + 0.001));
check("model: a line leaves when the next starts", Math.abs(model.lines[0].out - model.lines[1].t) < 0.001, model.lines[0]);
check("model: the last line before a pause is held, then goes", Math.abs(model.lines[9].out - (model.lines[9].end + 1.4)) < 0.001, model.lines[9]);
eq("lineAt: before", Parse.lineAt(model.lines, 2, 0.3), -1);
eq("lineAt: led", Parse.lineAt(model.lines, 7.8, 0.3), 0);
eq("lineAt: middle", Parse.lineAt(model.lines, 40, 0.3), 6);
eq("lineAt: after", Parse.lineAt(model.lines, 500, 0.3), 25);
eq("words: two under one time share it", Parse.wordsOf({end: 3, words: [{start: 1, end: 2, text: "oh yeah "}, {start: 2, end: 2, text: "now"}]}).map(w => w.text + "@" + w.t.toFixed(2) + "+" + w.d.toFixed(2)), ["oh@1.00+0.33", "yeah@1.33+0.67", "now@2.00+1.00"]);
{
  // The line-timed upload: each line's length shared out among its words, inside the line.
  const byLine = Parse.fromSheet(uploads[1]);
  eq("model: a line-timed sheet", [byLine.wordTimed, byLine.lines.length], [false, 25]);
  check("model: its words spread inside the line", byLine.lines[0].words.length === 6 && byLine.lines[0].end <= 12.8 && byLine.lines[0].words[5].t > 8.5, byLine.lines[0]);
  check("model: a blank stamp is where the last line of a verse ends", byLine.lines[3].end <= 26.74 + 0.001, byLine.lines[3]);
  eq("model: nothing to draw", Parse.fromSheet({source: "x", worded: false, lines: []}), null);
}

// ---- the song's clock: what a reading of the player's position says ----
{
  eq("clock: a reading as busctl writes it", Clock.parse("1000.250000 x 27861333"), {wall: 1000.25, position: 27.861333});
  eq("clock: a comma for the point, as a locale may write it", Clock.parse("1000,5 x 1000000"), {wall: 1000.5, position: 1});
  eq("clock: anything else", [Clock.parse(""), Clock.parse("Failed to get property")], [null, null]);
  // The shell is running the song on from 10 s at wall time 1000, and is asked at 1000.4.
  const said = (before, reading, rate = 1) => Clock.step({wall: 1000 + before[0], position: before[1]}, {wall: 1000 + reading[0], position: reading[1]}, 10 + rate * 0.4, 1000.4, rate);
  // A player that works its position out as it is asked, and is where the shell has it.
  const exact = said([0.2, 10.2], [0.28, 10.28]);
  check("clock: a position that moves with the readings, and agrees", exact.moved && exact.live && Math.abs(exact.ahead) < 1e-6, exact);
  // The same, but really 0.8 s behind.
  check("clock: one that is behind", Math.abs(said([0.2, 9.4], [0.28, 9.48]).ahead + 0.8) < 1e-6);
  // Renewed once a second and really 1.4 s behind (a track that loaded for 1.4 s): stale until
  // it steps, and at the step exact somewhere in the gap between the two readings.
  const stale = said([0.2, 8], [0.28, 8]);
  eq("clock: a position that has not moved says nothing", [stale.moved, stale.ahead], [false, null]);
  const stepped = said([0.36, 8], [0.44, 9]);
  check("clock: one renewed in steps is exact as it steps", stepped.moved && !stepped.live && stepped.stride === 1 && Math.abs(stepped.ahead + 1.4) < 0.045, stepped);
  check("clock: at another rate", Math.abs(said([0.36, 8], [0.44, 9], 1.5).ahead - (9 - (10 + 1.5 * 0.44) + 0.06)) < 1e-6);
  eq("clock: a reading across a jump is not believed", said([0.2, 108], [0.28, 0]).ahead, null);
}

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
