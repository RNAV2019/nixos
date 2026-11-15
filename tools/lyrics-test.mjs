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
const Kinetic = load("Kinetic.js", "spring, outBack, hash, pick, bare, pulse, smooth");

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
eq("emoji: endings", ["burning", "burnin'", "stars", "shining", "dreamed", "running"].map(Emoji.lookup), ["🔥", "🔥", "⭐", "✨", "💤", "🏃"]);
Emoji.annotate(model);
eq("emoji: marked", model.lines[7].words.map(w => w.emoji), ["", "", "🔥", "🔥", ""]);

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
check("plan: another song casts differently", JSON.stringify(Director.plan(model, catalogue, seed + 1).map(s => s.style)) !== JSON.stringify(plan.map(s => s.style)));

// ---- curves ----
check("spring: starts at rest", Kinetic.spring(0, 30, 0.6) === 0 && Kinetic.spring(-1, 30, 0.6) === 0);
check("spring: settles on 1", Math.abs(Kinetic.spring(2, 30, 0.6) - 1) < 1e-6);
check("spring: rings past 1 when underdamped", Math.max(...Array.from({length: 60}, (_, i) => Kinetic.spring(i / 120, 30, 0.6))) > 1.05);
check("spring: never past 1 when critical", Math.max(...Array.from({length: 240}, (_, i) => Kinetic.spring(i / 120, 30, 1))) <= 1);
check("hash: in range and repeatable", Kinetic.hash(7, 3, 2) === Kinetic.hash(7, 3, 2) && Kinetic.hash(7, 3, 2) >= 0 && Kinetic.hash(7, 3, 2) < 1);
eq("bare", ["night,", "(oh)", "don't", "go!"].map(Kinetic.bare), ["night", "oh", "don't", "go"]);

if (failed > 0) {
  console.error(`${failed} failed`);
  process.exit(1);
}
console.log("lyrics logic: ok");
