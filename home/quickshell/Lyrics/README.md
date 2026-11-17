# Lyrics

The words of what is playing, in the island's pill. While a song with timed lyrics plays, the
shut pill is the song's and not the clock's: the line being sung and nothing else, grown to the
line's width and no taller; three dots while nobody sings; the song's title at its start. The
clock and the equaliser are back when the last line has been sung, when the music is paused, and
for a song with no timed lyrics. ALT + L switches it off and on
(`qs ipc call lyrics toggle`), and the choice is kept in `~/.local/state/shell/lyrics`.

| File | What it is |
| --- | --- |
| `Sheets.js` | What each source answers, read into sheets: Apple Music's TTML, LRCLIB's word file, LRC. |
| `Rank.js` | Which sheet is for the recording that is playing, and which of those to show. |
| `Parse.js` | Names as players give them, and a sheet as the one shape the pill draws: lines, each word with its start and length. |
| `Clock.js` | What a reading of the player's position says about where the song really is. |
| `Pill.js` | Lines cut to the pill's width (phrases), when each comes and goes, what the pill is while nobody sings, and a word at a moment. |
| `LyricFace.qml` | What the pill draws in the clock's place: the line (two rows, the one up and the one leaving), the dots, the title. |
| `../Services/Lyrics.qml` | Fetching and keeping the words, the on/off switch, and the song's clock. |
| `../Bar/Island.qml` | `lyricUp`: when the pill is the song's, and what gives way to it. |
| `../Ui/CollapsedPill.qml` | The same face, drawn by a surface on its way out of the pill or back into it. |

The `.js` files are plain (no QML imports) and are run under node by `tools/lyrics-test.mjs`
(`nix flake check`, `checks.lyrics-logic`).

## How a line is drawn

Everything a word does is a function of the song's time (`Lyrics.now`, the player's position read
every frame, set right against the player and glided after; see "The song's time"), so the pill
at 38.2 s is the same picture every run.

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
island as the clock's pill (`Lyrics.faced` is down for it): asked for while the pill is a song's,
it waits (`Bus.lockHeld`, as for anything still coming to rest) until the words have gone and the
clock's pill is back, so the lock's own pill starts on it and its clock flies out of the pill's.
Unlocked, the clock lands in its pill and the words take it again half a second later. A camera, microphone or recording
mark stays, at the line's end; only the equaliser goes with the clock.

## The pointer

Over a line the hover card still opens, since it is where the clock is, but only for a pointer
that means it: it must travel 4 px on the pill and then stay 300 ms (70 ms on the plain pill). A
line that grows under a pointer at rest does not open it. A click on the words does
nothing (the card is open under the pointer before one could land on them); pinning the card is
a click on the open card, and a click on its track block plays or pauses.

## Where the words come from

From where Sonora's lyrics panel gets them, chosen by its rules (its `crates/music/src/lyrics`),
so the pill and the panel show the same sheet. Two sources are asked at once, neither needing a
key or an account, with the song's title, artists, album and length:

- **Apple Music's own sheets**, through the public catalogue of them Sonora asks
  (`lyrics-api.binimum.org`): the recordings it has under the name, each with where its TTML
  sheet is. The one that is playing is asked for (`Rank.pick`): timed word by word before timed
  by line, then the nearest in length. Voices behind a line are lines of their own, in brackets,
  where they are sung clear of it.
- **LRCLIB's search**: every upload for the song. An upload has an LRC timed by line and may
  have a word file timing every word; the file is read only for the upload that is shown.

`Rank.js` then decides. A sheet counts only if it is the song (title and one artist alike, by
their letters) and the recording: a length within ten seconds of the player's, since another
take keeps another time, and a wrong sheet is worse than none. Of those, a sheet that runs the
length of the song beats one that stops early; Apple's beats an upload; then the score, which
favours words timed one by one and the closest length. An upload timed word by word is set on
the lines of the best line-timed upload (`Rank.conform`), since those are the ones people
proofread. Apple's whole sheet is taken the moment it arrives; anything else waits for both
sources. A song neither has shows the plain pill.

The answer is kept in `~/.cache/quickshell/lyrics`, so a song is asked for once; one chosen
while a source could not be reached is kept for the session only. `qs ipc call lyrics source`
says whose sheet is up and how it is timed.

## The song's time

A player's position is run on by the shell between the player's reports, so it is as good as the
last report. Sonora's is not good to the second: a track is "Playing" while it still loads, the
position it gives is renewed once a second, and it says the track has jumped only when it is two
seconds out. Run on from one such reading, the words were up to two seconds early for the whole
of a song that took a moment to start. So while there are words to show the player is asked
directly (`Services/Lyrics.qml`, "the song's clock"): a burst of eighteen readings over a second
and a bit, when the song starts or jumps and every twelve seconds after. A position that moved
with the readings is exact; one renewed in steps is exact as it steps (`Clock.js`).
`Lyrics.correction` is what the run-on position is out by. A player that is known to move finely
and stands still through a burst is waiting, and the song's time waits with it
(`Lyrics.holding`). A player whose position never moves between its reports is left as it is.
`qs ipc call lyrics clock` says where the song is and what it was set right by.

## Testing

`tools/qs-verify/lyrics.sh` runs the pill on the headless harness with a mock player and the
fixture song, which the harness's `curl` answers for both sources: `up`, `sync`, `frames OUT
T...` (the island with the song held at each moment, via `qs ipc call lyrics pin`), `strip`,
`play`, `down`. With `QSV_PLAYER=stepped` at `up` the mock player keeps time as Sonora tells it
(a second and a half of loading, a position renewed once a second), and `clock` starts the song
anew and prints, second by second, where it really is and where the shell has it. In the fixture the title is up until 7.6 s,
the dots stand from 56.6 to 63.6 s, and the last line has gone by 137 s; `qs ipc call lyrics
face` says which it is.
