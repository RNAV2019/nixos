# Lyrics

The lyric stage: one screen given over to the words of what is playing, set in motion, in a new
style for each part of the song. `qs ipc call lyrics toggle` (ALT + L) brings it up and puts it
away.

## How it fits together

- **`Services/Lyrics.qml`** fetches the song's timed words while the stage is up (LyricsPlus for
  word timings and the song's parts, LRCLIB for line timings as the fallback), keeps each answer
  in `~/.cache/quickshell/lyrics`, and publishes one `model`.
- **`Parse.js`** turns either service's answer into that model: `lines` of `words`, every time in
  seconds, each line knowing when it ends (`end`) and when it should leave (`out`), and `parts`
  with a tier: `calm`, `mid` or `high`.
- **`Emoji.js`** marks each word that has an obvious picture (`word.emoji`).
- **`Director.js`** cuts the song into segments of about ten seconds and casts a style for each
  from the catalogue (`LyricScene.catalogue`), by tier and by a seed made from the song, so a
  song is always cast the same way and no style comes round again until three others have played.
  A stretch with nothing sung is a segment in the style `Interlude`.
- **`LyricStage.qml`** is the window, the keys and the fade. **`LyricScene.qml`** is the picture:
  the clock, the ground (`Shaders/lyricground.frag`), the style in hand, and the lens
  (`Shaders/lyricpost.frag`, fed its bloom by `lyricblur.frag`).
- **`Styles/*.qml`** are the styles, each a `LyricStyle`.

## Writing a style

A style is one file in `Styles/`, named for what it does, whose root is `LyricStyle`. It is
handed `stage` and `seg` and draws lines `first..last` of `lines`. Read `Styles/Punch.qml` (a
word at a time) and `Styles/Poster.qml` (a whole segment laid out, with a camera) before
writing one.

What `LyricStyle` gives you:

| | |
| --- | --- |
| `now` | the song's time in seconds, new every frame |
| `lines`, `first`, `last` | the song's lines and this segment's range |
| `cur`, `line` | the line in hand (`-1` / `null` before the segment's first), counted from `lead` seconds before its first word |
| `u` | a hundredth of the stage's height: size everything in it |
| `ink`, `accent`, `accent2` | warm white, and two colours from the cover |
| `seed` | this segment's own number, for `Kinetic.hash/jitter/pick` |
| `slotLine(k, n)` | the line slot `k` of an `n`-slot pool draws (see Punch) |
| `face(i, j)` | a face from `Theme.lyricFaces` for word `j` of line `i` |
| `until(line, j)` | when word `j` gives way to the next |
| `mix(a, b, t)` | a colour between two |
| `stage.wall` | seconds that never stop, for drift that should not follow the song |
| `stage.kick`, `stage.level` | the landing word's hit (0..1, dying away) and the player's loudness |
| `stage.stir` | the kicks so far, summed: add it to `stage.wall` for drift that lurches on each word |

A word is `{ t, d, text, emoji }`; a line is `{ t, end, out, text, words, part, index }`.

The rules that keep every style honest:

- **Everything is a function of `now`.** No `Timer`, `Behavior`, `NumberAnimation` or state kept
  between frames for the words: ask `Kinetic.spring(now - word.t, omega, zeta)` and its
  neighbours how far along a thing is. Then a seek, a pause and a test frame pinned at 38.2 s all
  draw the same picture. (`stage.wall` is there for idle drift only.)
- **A word is not there before it is sung** unless the style is about the line waiting (then it
  waits dim). A line is gone by its `out`. Before `cur` reaches the segment's first line draw
  nothing.
- **Never name an id `style`.** `Text` has a `style` property, so inside any text `style.u`
  reads the wrong thing. The root is `sty` everywhere.
- **Set `size` once and move with `scale`.** `LyricText` draws from outlines (the curve
  renderer), so it is sharp at any scale; `font.pixelSize` is a whole number and changing it lays
  the word out again. Fit a word or a row with `scale: room / implicitWidth`.
- **Any line, any song.** One word or fourteen, a word of twenty letters, a line of half a
  second: fit to the stage's width, never run off it, never overlap what is still being read.
- **Black is the ground.** The panel is an OLED and the picture is light on black: no filled
  backdrops, nothing that sits still for the length of a segment, small plates behind words at
  most.
- **Keep it cheap.** It runs at 2880 x 1800 and 120 Hz on integrated graphics. Hide what is out
  of its life (`visible: false`), keep under a hundred or so texts alive, no `layer.enabled`
  or `MultiEffect` per word (one or two per style at most, always on, never toggled), no
  `Canvas`.
- **A style is one file.** Styles are loaded by path, so a helper type in a file beside one is
  never found (it "is not a type", and the stage falls back to `Interlude`): nest what a style
  needs as delegates inside it. A type several styles share goes in `Lyrics/` itself, like
  `LyricEmoji`. No inline `component`, as everywhere in the shell.
- **The traps others have fallen in.** `left`, `right`, `top`, `bottom` and `baseline` cannot be
  property names (they are an item's anchor lines; the file fails to load). `Row` and `Column`
  close up over a child with `visible: false`: hide a word that must keep its room with
  `opacity: 0`. A binding on `repeater.itemAt(i)` runs once and never again: read
  `repeater.count` in it too. A pooled slot changes line a frame before its inner delegates
  follow, so guard `line.words[j]` with `j < line.words.length`, or hand the delegates the word
  itself.
- **The lens is yours to set**: `bloom`, `aberration`, `warp`, `scan`, `grain`, `vignette`,
  `ground`, and the `...Kick` ones (`bloomKick`, `aberrationKick`, `punchKick`, `glitchKick`,
  `shakeKick`, `flashKick`) that are added as each word lands. They are what makes a style feel
  like itself; a quiet style turns them down, a loud one up. No flashing the whole frame white.
- **An old print.** Root a style in `FilmStyle` instead of `LyricStyle` and it is seen black and
  white, soft, dusty and flickering (the lens's `mono`, `dust` and `flicker`), as `Reel`, `Ring`
  and `Titlecard` are; `spot`, `spotAt` and `spotSize` put the projector's lamp behind the words.
- **Letters** that come and go one by one are `LyricLetters`: a word drawn a letter at a time
  where the whole word would put them, in order or scattered (`scattered`), blinking out now and
  then (`flicker`), leaving one by one (`gone`).
- **Pictures** are `LyricEmoji { glyph: word.emoji; size: ... }` where `word.emoji !== ""`.
- **Faces** come from `Theme.lyricFaces` (through `face(i, j)` or by family: `Theme.lyric*Font`).
  A face that is missing falls back, so check a frame, not the name.

To cast it, add it to `LyricScene.catalogue` with its tiers.

## Looking at one

```sh
tools/qs-verify/lyrics.sh up                                  # once: harness, faces, player, song
tools/qs-verify/lyrics.sh sync                                # after every edit
tools/qs-verify/lyrics.sh frames /tmp/out Punch 38.3 41.0     # frames at moments of the song
tools/qs-verify/lyrics.sh strip /tmp/out Punch 38.0 39.4 12   # twelve frames as one sheet
tools/qs-verify/lyrics.sh log                                 # what the shell warned of
tools/qs-verify/lyrics.sh down
```

`QS_VERIFY_WORK=/tmp/qsv-mine` gives a second harness beside another. `QS_SETTLE=1.6` gives a
busy machine longer between a pin and its capture (the first frame after a change of style is
the one that comes out stale). `down` removes the harness's whole folder, so keep the pictures
somewhere else. If the shell under test crashes, Quickshell starts it again by itself with the
files it had, and that copy would go on answering in place of the one a `sync` starts: `log` says
when there is a crash report, and `sync` puts any such copy down first. The fixture song is in
`tools/qs-verify/fixtures/lyrics-plus.json`; `tools/lyrics-test.mjs` checks the parsing, the
plan and the curves under node, and `nix flake check` runs it.
