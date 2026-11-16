#!/usr/bin/env node
// lyrics-test.mjs — how a lyrics service's answer is read (home/quickshell/Lyrics/Parse.js), run
// under node on the harness's fixture song.
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

if (failed > 0) {
  console.error(`${failed} failed`);
  process.exit(1);
}
console.log("lyrics logic: ok");
