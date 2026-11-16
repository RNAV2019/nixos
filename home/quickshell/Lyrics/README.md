# Lyrics

The words of what is playing, in the island's pill. While a song with timed lyrics plays, the
shut pill is the song's and not the clock's: the line being sung and nothing else, grown to the
line's width and no taller; three dots while nobody sings; the song's title at its start. The
clock and the equaliser are back when the last line has been sung, when the music is paused, and
for a song with no timed lyrics. ALT + L switches it off and on
(`qs ipc call lyrics toggle`), and the choice is kept in `~/.local/state/shell/lyrics`.

| File | What it is |
| --- | --- |
| `Parse.js` | A lyrics service's answer as one shape: lines, each word with its start and length. |
| `Pill.js` | Lines cut to the pill's width (phrases), when each comes and goes, what the pill is while nobody sings, and a word at a moment. |
| `LyricFace.qml` | What the pill draws in the clock's place: the line (two rows, the one up and the one leaving), the dots, the title. |
| `../Services/Lyrics.qml` | Fetching and keeping the words, the on/off switch, and the song's clock. |
| `../Bar/Island.qml` | `lyricUp`: when the pill is the song's, and what gives way to it. |
| `../Ui/CollapsedPill.qml` | The same face, drawn by a surface on its way out of the pill or back into it. |

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

## While nobody sings

`Pill.faceAt` says what the pill is at a moment of the song; `Lyrics.face` carries it.

- **The title.** At the song's start the pill names it: the title in the words' own face, the
  artist beside it and fainter where both fit. It stands until the first line, or for seven
  seconds where the intro is long enough to leave the dots two more. A song that starts singing
  inside two and a half seconds is not named.
- **The dots.** With a line still to come (the rest of an intro, a pause between verses), three
  dots in a small pill. They breathe while they wait and are lit one by one over the last six
  seconds before the voice, so the eye knows when to come back.
- **The clock's pill.** After the last line there is nothing to wait for.

## What gives way to what

The song's face is still the resting pill, only a wider or narrower one: `Lyrics.pillWidth` is
the shut pill's width whatever it shows, the island rests at it, and every surface that grows out
of the island starts from it and comes back to it (`IslandOrigin.collapsedWidth`). Because the
face is drawn from the song's time alone, a surface draws the same words as the island would
(`Ui/CollapsedPill.qml`, by `IslandOrigin.fromFace` on the way out and `Lyrics.faced` on the way
back): a panel's first frame matches the line it covers and the words fade as it grows, and
closing it shrinks straight into the line, the dots or the title, which the island under it has
gone on following unseen.

The open hover card and the drop well are the island's own shapes and take the face down
(`lyricUp`). The card on its way shut keeps its clock until it is nearly the pill, then gives way
to the words, and lands on the line's width without stopping at the clock's. A lock takes the
island as the clock's pill (`Lyrics.faced` is down for it). A camera, microphone or recording
mark stays, at the line's end; only the equaliser goes with the clock.

## The pointer

Over a line the hover card still opens, since it is where the clock is, but only for a pointer
that means it: it must travel 4 px on the pill and then stay 300 ms (70 ms on the plain pill). A
line that grows under a pointer at rest does not open it. A click on the words does
nothing (the card is open under the pointer before one could land on them); pinning the card is
a click on the open card, and the Now playing panel a click on its track block, as ever.

Words come from LyricsPlus (word timings) or LRCLIB (line timings, the words then spread by
syllable), asked once a song and kept in `~/.cache/quickshell/lyrics`. A song neither has shows
the plain pill.

## Testing

`tools/qs-verify/lyrics.sh` runs the pill on the headless harness with a mock player and the
fixture song: `up`, `sync`, `frames OUT T...` (the island with the song held at each moment, via
`qs ipc call lyrics pin`), `strip`, `play`, `down`. In the fixture the title is up until 7.6 s,
the dots stand from 56.6 to 63.6 s, and the last line has gone by 137 s; `qs ipc call lyrics
face` says which it is.
