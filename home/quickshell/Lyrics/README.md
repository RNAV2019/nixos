# Lyrics

The words of what is playing, in the island's pill. While a song with timed lyrics plays, the
shut pill is the line being sung and nothing else: it grows to the line's width, no taller, and
the clock and the equaliser are back in every pause. ALT + L switches it off and on
(`qs ipc call lyrics toggle`), and the choice is kept in `~/.local/state/shell/lyrics`.

| File | What it is |
| --- | --- |
| `Parse.js` | A lyrics service's answer as one shape: lines, each word with its start and length. |
| `Pill.js` | Lines cut to the pill's width (phrases), when each comes and goes, and a word at a moment. |
| `LyricLine.qml` | The line as the pill draws it: two rows, the one up and the one leaving. |
| `../Services/Lyrics.qml` | Fetching and keeping the words, the on/off switch, and the song's clock. |
| `../Bar/Island.qml` | `lyricUp`: when the pill is a line, and what gives way to it. |

Both `.js` files are plain (no QML imports) and are run under node by `tools/lyrics-test.mjs`
(`nix flake check`, `checks.lyrics-logic`).

## How a line is drawn

Everything a word does is a function of the song's time (`Lyrics.now`, the player's position read
every frame and glided after), so the pill at 38.2 s is the same picture every run.

- **Coming up.** A phrase is up `LEAD` (0.25 s) before its first word, never before the phrase in
  front has been sung through. Its words rise 7 px into place, 30 ms apart.
- **Being sung.** A word not yet sung is ink at 34%. As it is sung a front 2.2 letters wide passes
  over it, each letter going to full ink behind it (`Pill.swept`: styled text, a colour a
  letter, so the word keeps its kerning and nothing is drawn through a layer). The word stands
  1.1 px proud of the line while it is sung, and one that is held grows a little (4%, 1.6 px at
  most). Sung, it eases back to 80%, so the word in the voice is the brightest thing in the pill.
- **Leaving.** The line fades and lifts 8 px over 0.2 s as the next comes up under it.
- **The pill.** Its width is the island's own spring, to the phrase's measured width plus
  `Theme.islandLyricInset` either side. From the plain pill it starts `EARLY` (0.16 s) before the
  words, so the clock is gone and the room is there when they come; after a phrase nothing
  follows (a pause over three seconds, `Parse.js`) the words go first and the clock comes back.

A line too wide for the pill (`Theme.islandLyricMaxText`, the open card's width less the insets)
is cut into the fewest even stretches that fit, at a comma where there is one, and each stretch is
shown as its own phrase as it is sung.

## What gives way to what

The words are the resting pill's and nothing else's. The open card, a panel or the volume bar
over the island, the drop well and the lock all take them down (`lyricBlocked`), and the plain
pill stands 320 ms after any of them before the words take it again. A surface that takes the
island while a line is up grows out of the line's shape (the pill is then not `resting`, so it is
on offer like the open card, with `clockShown` false). A camera, microphone or recording mark
stays, at the line's end; only the equaliser goes with the clock. Paused, the plain pill is back.

Words come from LyricsPlus (word timings) or LRCLIB (line timings, the words then spread by
syllable), asked once a song and kept in `~/.cache/quickshell/lyrics`. A song neither has shows
the plain pill.

## Testing

`tools/qs-verify/lyrics.sh` runs the pill on the headless harness with a mock player and the
fixture song: `up`, `sync`, `frames OUT T...` (the island with the song held at each moment, via
`qs ipc call lyrics pin`), `strip`, `play`, `down`.
