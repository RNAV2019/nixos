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
- **`LyricStage.qml`** is the window, the keys and the way in and out: the desktop, caught as a
  picture, goes out of focus from the top down and dark, and the stage comes out of the same
  blur (`Shaders/lyricfold.frag`; `qs ipc call lyrics fold 0.4` holds it part-way for a look).
  **`LyricScene.qml`** is the picture:
  the clock, the ground (`Shaders/lyricground.frag`), the style in hand, and the lens
  (`Shaders/lyricpost.frag`, fed its bloom by `lyricblur.frag`).
- **`Styles/*.qml`** are the styles, each a `LyricStyle`.

## Writing a style

A style is one file in `Styles/`, named for what it does, whose root is `LyricStyle`. It is
handed `stage` and `seg` and draws lines `first..last` of `lines`. Read `Styles/Punch.qml` (a
word at a time), `Styles/Cascade.qml` (a line built word by word in two faces) and
`Styles/Stack.qml` (the column every lyrics player draws) before writing one.

What `LyricStyle` gives you:

| | |
| --- | --- |
| `now` | the song's time in seconds, new every frame |
| `lines`, `first`, `last` | the song's lines and this segment's range |
| `cur`, `line` | the line in hand (`-1` / `null` before the segment's first), counted from `lead` seconds before its first word |
| `u` | a hundredth of the stage's height: size everything in it |
| `ink` | what words are set in: near white, leaning the cover's way |
| `accent` | the cover's liveliest colour, for the word in hand or the words the singer leans on |
| `accent2`, `accent3` | two more the cover has (the ground is lit with all three) |
| `dim` | a word not yet sung |
| `seed` | this segment's own number, for `Kinetic.hash/jitter/pick` |
| `slotLine(k, n)` | the line slot `k` of an `n`-slot pool draws (see Punch) |
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
- **Out of focus** is the stage's soft plate: parent an item to `stage.softPlate`, set `softens`
  and a `softRadius` (in `u`), and it is drawn blurred by that much and added to the picture as
  light, under whatever of yours is sharp (`Reel`'s title behind its script). There is one
  plate and one blur for the whole stage, and they last as long as it does.
- **Black is the ground.** The panel is an OLED and the picture is light on black: no filled
  backdrops, nothing that sits still for the length of a segment, small plates behind words at
  most. The film styles are the exception, and on purpose: their blacks are lifted to a grainy
  grey (`veil`), because the print they copy has none.
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
- **Every colour is the cover's** (`Palette.js`), so each song looks like itself. Words are
  `ink`; `accent` marks the word in hand or the words the singer leans on, never a whole line,
  and never more than one colour of type at a time; a word not yet sung is `dim`. The film
  styles stay black and white, toned the cover's way (the stage's `tone`).
- **Two faces at most, each with a part to play** (capitals for the passing words and an italic
  for the ones the singer leans on, say). A face per word looks drawn from a hat.
- **Nothing bounces, shakes or flashes.** Things settle (`Kinetic.spring(age, omega, 1)` or an
  ease out); a hit is told by the type and by the lens's `punchKick` in a chorus style, never by
  squash, wobble or confetti.
- **A change of style is a pull of focus**, and the stage's to make: the lens goes soft over
  the last of the style leaving and sharp over the first of the one arriving. A style need do
  nothing for it but have its line gone by `out`.
- **The lens is yours to set**: `bloom`, `grain`, `vignette`, `ground`, the `...Kick` ones
  (`bloomKick`, `punchKick`) that are added as each word lands, and `depth`, `depthAt` and
  `depthBand`, which put everything above and below one band of the stage out of focus (how
  `Stack` softens the lines round the one in hand). Blur belongs there: an item blurred by a
  layer of its own is made and thrown away with its line, and that is where the one crash the
  stage has had came from.
- **An old print.** Root a style in `FilmStyle` instead of `LyricStyle` and it is seen black and
  white, soft, grey-black, dusty and flickering (the lens's `mono`, `veil`, `softness`, `dust`
  and `flicker`), as `Reel`, `Ring`
  and `Titlecard` are; `spot`, `spotAt` and `spotSize` put the projector's lamp behind the words.
  The look is not switched on with the style. Which stretches are a print is in the plan (the
  catalogue's `look: "film"`; a pause keeps the look of what it follows), and the stage takes
  the lens over to Theme's `lyricFilm...` settings along the song's time, starting a little
  before the change and done a second and a half after it on the print's side
  (`Director.lookAt`), the dust and flicker last to come and first to go. So a print is never
  cut to or from, and a frame pinned anywhere in a change is the same every run.
- **Letters** that come and go one by one are `LyricLetters`: a word drawn a letter at a time
  where the whole word would put them, in order or scattered (`scattered`), blinking out now and
  then (`flicker`), leaving one by one (`gone`).
- **Pictures** are `LyricEmoji { glyph: word.emoji; size: ... }` where `word.emoji !== ""`.
- **Faces** are named by `Theme.lyric*Font` (the shell's display face and `pkgs/lyric-fonts`).
  A face that is missing falls back, so check a frame, not the name.

To cast it, add it to `LyricScene.catalogue` with its tiers.

## Looking at one

```sh
tools/qs-verify/lyrics.sh up                                  # once: harness, faces, player, song
tools/qs-verify/lyrics.sh sync                                # after every edit
tools/qs-verify/lyrics.sh frames /tmp/out Punch 38.3 41.0     # frames at moments of the song
tools/qs-verify/lyrics.sh strip /tmp/out Punch 38.0 39.4 12   # twelve frames as one sheet
tools/qs-verify/lyrics.sh probe Punch 8.6                     # what a frame costs each thread
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
