#!/usr/bin/env node
// lyrics-test.mjs — the lyric stage's plain logic (home/quickshell/Lyrics/{Parse,Director,
// Emoji,Kinetic}.js), run under node on the harness's fixture song.
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
const Director = load("Director.js", "hashText, rng, plan, segmentAt");
const Emoji = load("Emoji.js", "lookup, annotate");
const Palette = load("Palette.js", "roles, hueGap");
const Kinetic = load("Kinetic.js", "spring, outBack, hash, pick, bare, pulse, smooth, span, rows, flick, scatter");

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

// ---- pictures ----
eq("emoji: plain", ["fire", "heart", "the", "Moon,", "a"].map(Emoji.lookup), ["🔥", "❤️", "", "🌙", ""]);
eq("emoji: endings", ["burning", "burnin'", "stars", "waves", "dreamed", "running"].map(Emoji.lookup), ["🔥", "🔥", "⭐", "🌊", "💤", "🏃"]);
Emoji.annotate(model);
eq("emoji: marked, a picture once a line", model.lines[7].words.map(w => w.emoji), ["", "", "🔥", "", ""]);
eq("emoji: no sparkles", ["afterglow", "shine", "magic"].map(Emoji.lookup), ["", "", ""]);

// ---- the plan ----
const catalogue = [
  {name: "Calm1", tiers: ["calm"]}, {name: "Calm2", tiers: ["calm", "mid"]},
  {name: "Mid1", tiers: ["mid"]}, {name: "Mid2", tiers: ["mid"]}, {name: "Mid3", tiers: ["mid", "high"]},
  {name: "High1", tiers: ["high"]}, {name: "High2", tiers: ["high"]},
  {name: "Pictures", tiers: ["mid", "high"], wants: "emoji"},
];
const seed = Director.hashText("mira-okafor-glass-harbour-152");
const plan = Director.plan(model, catalogue, seed);
eq("plan: repeatable", Director.plan(model, catalogue, seed), plan);
eq("plan: opens on an interlude", [plan[0].style, plan[0].t0, plan[0].firstLine], ["Interlude", -Infinity, -1]);
eq("plan: ends on an interlude", [plan[plan.length - 1].style, plan[plan.length - 1].t1], ["Interlude", Infinity]);
check("plan: no gaps", plan.every((s, i) => i === 0 || s.t0 === plan[i - 1].t1), plan.map(s => [s.t0, s.t1]));
check("plan: every line once", (() => {
  const seen = [];
  plan.forEach(s => { for (let i = s.firstLine; i >= 0 && i <= s.lastLine; i++) seen.push(i); });
  return JSON.stringify(seen) === JSON.stringify(model.lines.map((_, i) => i));
})());
check("plan: the pause after the first chorus is an interlude", plan.some(s => s.style === "Interlude" && s.t0 > 55 && s.t1 < 64.1), plan.map(s => [s.style, s.t0, s.t1]));
check("plan: a style fits its tier", plan.every(s => s.style === "Interlude" || catalogue.find(c => c.name === s.style).tiers.includes(s.tier)));
check("plan: no style twice running", plan.filter(s => s.firstLine >= 0).every((s, i, a) => i === 0 || s.style !== a[i - 1].style), plan.map(s => s.style));
check("plan: pictures only where there are some", plan.filter(s => s.style === "Pictures").every(s => {
  let n = 0;
  for (let i = s.firstLine; i <= s.lastLine; i++) n += model.lines[i].words.filter(w => w.emoji).length;
  return n >= 2;
}));
check("plan: seeds differ", new Set(plan.map(s => s.seed)).size === plan.length);
eq("plan: segment at", [Director.segmentAt(plan, 0), Director.segmentAt(plan, 8), Director.segmentAt(plan, 1e6)], [0, 1, plan.length - 1]);
eq("plan: a song with no words", Director.plan({lines: [], parts: []}, catalogue, 1).map(s => s.style), ["Interlude"]);
check("plan: looks come in runs", (() => {
  const looks = [{name: "A", tiers: ["mid", "high", "calm"], look: "film"}, {name: "B", tiers: ["mid", "high", "calm"], look: "film"}, {name: "C", tiers: ["mid", "high", "calm"]}, {name: "D", tiers: ["mid", "high", "calm"]}];
  let same = 0, pairs = 0;
  for (let seed = 1; seed <= 40; seed++) {
    const cast = Director.plan(model, looks, seed).filter(s => s.firstLine >= 0).map(s => looks.find(c => c.name === s.style).look || "");
    for (let i = 1; i < cast.length; i++) { pairs++; if (cast[i] === cast[i - 1]) same++; }
  }
  // With no leaning a style would follow its own look a third of the time (one of three others).
  return same / pairs > 0.45;
})());
check("plan: another song casts differently", JSON.stringify(Director.plan(model, catalogue, seed + 1).map(s => s.style)) !== JSON.stringify(plan.map(s => s.style)));

// ---- the cover's colours ----
const sleeve = [{h: 0.02, s: 0.75, l: 0.45}, {h: 0.55, s: 0.6, l: 0.3}, {h: 0.12, s: 0.5, l: 0.8}, {h: 0, s: 0.02, l: 0.05}, {h: 0, s: 0, l: 0.97}];
const parts = Palette.roles(sleeve);
eq("palette: no cover, no parts", Palette.roles([]), null);
check("palette: found colour", parts.found === true);
check("palette: the accent is the liveliest, and reads on black", Palette.hueGap(parts.accent.h, 0.02) < 0.001 && parts.accent.l >= 0.66 && parts.accent.s >= 0.5, parts.accent);
check("palette: the second is the furthest the cover has", Palette.hueGap(parts.second.h, 0.55) < 0.001, parts.second);
check("palette: the third is apart from both", Palette.hueGap(parts.third.h, 0.12) < 0.001, parts.third);
check("palette: ink is near white and leans the accent's way", parts.ink.l > 0.9 && parts.ink.s <= 0.4 && parts.ink.h === parts.accent.h, parts.ink);
check("palette: dim is darker than ink", parts.dim.l < 0.65);
check("palette: the tone is barely a colour", parts.tone.s <= 0.2 && parts.tone.s > 0);
const one = Palette.roles([{h: 0.6, s: 0.7, l: 0.5}, {h: 0.6, s: 0.5, l: 0.3}]);
check("palette: one hue still gives three apart", Palette.hueGap(one.second.h, one.accent.h) > 0.05 && Palette.hueGap(one.third.h, one.accent.h) > 0.05, one);
const grey = Palette.roles([{h: 0, s: 0.03, l: 0.9}, {h: 0, s: 0, l: 0.1}, {h: 0.3, s: 0.1, l: 0.5}]);
check("palette: a black-and-white sleeve is greys", grey.found === false && grey.accent.s <= 0.08 && grey.tone.s === 0, grey);

// ---- curves ----
check("spring: starts at rest", Kinetic.spring(0, 30, 0.6) === 0 && Kinetic.spring(-1, 30, 0.6) === 0);
check("spring: settles on 1", Math.abs(Kinetic.spring(2, 30, 0.6) - 1) < 1e-6);
check("spring: rings past 1 when underdamped", Math.max(...Array.from({length: 60}, (_, i) => Kinetic.spring(i / 120, 30, 0.6))) > 1.05);
check("spring: never past 1 when critical", Math.max(...Array.from({length: 240}, (_, i) => Kinetic.spring(i / 120, 30, 1))) <= 1);
check("hash: in range and repeatable", Kinetic.hash(7, 3, 2) === Kinetic.hash(7, 3, 2) && Kinetic.hash(7, 3, 2) >= 0 && Kinetic.hash(7, 3, 2) < 1);
eq("scatter: every place once", [0, 1, 2, 3, 4, 5, 6].map(k => Kinetic.scatter(5, 1, 7, k)).sort(), [0, 1, 2, 3, 4, 5, 6]);
check("scatter: repeatable", Kinetic.scatter(5, 1, 7, 3) === Kinetic.scatter(5, 1, 7, 3));
check("flick: the same answer within a twelfth of a second", Kinetic.flick(9, 2, 3, 10.01, 0.5) === Kinetic.flick(9, 2, 3, 10.07, 0.5));
check("flick: about as often as asked", (() => {
  let off = 0;
  for (let step = 0; step < 4000; step++)
    if (Kinetic.flick(9, step % 7, step % 11, step / 12 + 0.01, 0.05) === 0)
      off++;
  return off > 120 && off < 280;
})());
eq("flick: never, when told never", Kinetic.flick(9, 2, 3, 10, 0), 1);
eq("rows: a word or two is one row", Kinetic.rows([{text: "Hold"}, {text: "on"}]), [[0, 1]]);
check("rows: every word once, in order", JSON.stringify(Kinetic.rows(model.lines[1].words).flat()) === JSON.stringify(model.lines[1].words.map((_, i) => i)));
eq("span: a stretch that never comes is 0, not NaN", [Kinetic.span(Infinity, Infinity, 5), Kinetic.smooth(Infinity, Infinity, 5), Kinetic.span(2, 2, 1), Kinetic.span(2, 2, 3)], [0, 0, 0, 1]);
eq("bare", ["night,", "(oh)", "don't", "go!"].map(Kinetic.bare), ["night", "oh", "don't", "go"]);

if (failed > 0) {
  console.error(`${failed} failed`);
  process.exit(1);
}
console.log("lyrics logic: ok");
