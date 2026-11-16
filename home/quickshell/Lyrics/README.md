# Lyrics

The lyric stage: one screen given over to the words of what is playing, set in motion.
`qs ipc call lyrics toggle` (ALT + L) brings it up and puts it away. The desktop fades slowly to
black and the words come up out of the black; it goes back much faster than it came.

There are three styles, and it opens in the first. **N** steps to the next and **P** to the
previous, round the list either way (`Theme.lyricStyles`); the style stays as it was left for as
long as the shell runs.

- **Poster**: each line set as a block of rows of one width, heavy and light, a word landing as
  it is sung; the camera travels and turns from one line's block to the next.
- **Drift**: the lines as a wall seen from one side, swaying; the line in hand sharp, the rest
  out of focus, each word filling with colour as it is sung.
- **Punch**: one word at a time owning the screen, stretching for as long as it is held, the
  line small underneath.

The other keys: Escape, Q or a click puts it away, Space plays and pauses, the arrows skip, and
`[` and `]` slide the words against the player's clock a twentieth of a second at a time (kept in
the state `lyrics-offset`).

## How it fits together

- **`Services/Lyrics.qml`** fetches the song's timed words while the stage is up (LyricsPlus for
  word timings, LRCLIB for line timings as the fallback), keeps each answer in
  `~/.cache/quickshell/lyrics`, and publishes one `model`.
- **`Parse.js`** turns either service's answer into that model: `lines` of `words`, every time in
  seconds, each line knowing when it ends (`end`) and when it should leave (`out`).
- **`Palette.js`** reads the parts the cover's colours play: the ink, the accent and a dim for
  the type, lifted to read, and the `wash`, three of the cover's colours as they are on the
  sleeve, which is what the ground is lit with (the one the cover has most of is the broadest).
- **`LyricStage.qml`** is the window, the keys and the way in and out. The window is clear and
  a black sheet fades up in it, so it is the desktop itself that fades, not a picture of it
  (`qs ipc call lyrics fade 0.4` holds the way in part-way for a look).
- **`LyricScene.qml`** is the picture: the clock, the cover's colours, the ground
  (`Shaders/lyricground.frag`), the style in hand, the lens (`Shaders/lyricpost.frag`), and over
  the lens the song's name in a corner.
- **`Styles/*.qml`** are the styles, each a `LyricStyle`.

## Writing a style

A style is one file in `Styles/`, named for what it does, whose root is `LyricStyle`. It is
handed `stage` and the song's `lines` and draws the whole song. To have N and P reach it, add its
name to `Theme.lyricStyles`.

What `LyricStyle` gives you:

| | |
| --- | --- |
| `now` | the song's time in seconds, new every frame |
| `lines` | the song's lines |
| `cur`, `line` | the line in hand (`-1` / `null` before the first), counted from `lead` seconds before its first word |
| `u` | a hundredth of the stage's height: size everything in it |
| `ink` | what words are set in: near white, leaning the cover's way |
| `accent` | the cover's liveliest colour, lifted to read on the ground, for the word in hand |
| `dim` | a word not yet sung |
| `slotLine(k, n, after)` | the line slot `k` of an `n`-slot pool draws (see Punch) |
| `until(line, j)` | when word `j` gives way to the next |
| `sung(line, j)` | when word `j` has been sung |
| `parting(line)` | whether a pause follows the line, so it goes on its own |
| `mix(a, b, t)` | a colour between two |
| `stage.wall` | seconds that never stop, for drift that should not follow the song |
| `stage.kick`, `stage.level` | the landing word's hit (0..1, dying away) and the player's loudness |

A word is `{ t, d, text }`; a line is `{ t, end, out, text, words, index }`.

The rules that keep every style honest:

- **Everything is a function of `now`.** No `Timer`, `Behavior`, `NumberAnimation` or state kept
  between frames for the words: ask `Kinetic.spring(now - word.t, omega, zeta)` and its
  neighbours how far along a thing is. Then a seek, a pause and a test frame pinned at 38.2 s all
  draw the same picture. (`stage.wall` is there for idle drift only.)
- **Never name an id `style`.** `Text` has a `style` property, so inside any text `style.u`
  reads the wrong thing. The root is `sty` everywhere.
- **Set `size` once and move with `scale`.** `LyricText` draws from outlines (the curve
  renderer), so it is sharp at any scale; `font.pixelSize` is a whole number and changing it lays
  the word out again. Fit a word or a row with `scale`. (Punch's letter spacing is the one thing
  laid out again each frame, for the one word that is up.)
- **Measure with a metrics item and read its `height` in the binding.** `advanceWidth()` is a
  plain call that nothing watches, so a binding that only calls it keeps what it measured before
  the face was there.
- **Any line, any song.** One word or fourteen, a word of twenty letters, a line of half a
  second: fit to the stage's width, never run off it, never overlap what is still being read.
- **The ground is the cover's.** It is lit in the sleeve's own colours, drifting, and never
  brighter than white type reads on: no filled backdrops of a style's own, nothing that sits
  still for the length of a song (the panel is an OLED).
- **Keep it cheap.** It runs at 2880 x 1800 and 120 Hz on integrated graphics. Draw lines from a
  small pool of slots (`slotLine`), hide what is out of its life (`visible: false`), no
  `layer.enabled` or `MultiEffect` per word, no `Canvas`.
- **Blur is the lens's.** Set `depth`, `depthAt` and `depthBand` and everything above and below
  one band of the stage goes out of focus (how Drift softens the lines round the one in hand,
  and how Punch softens a word as it lands). The song's name is drawn over the lens and stays
  sharp.
- **A style is one file.** Styles are loaded by path, so a helper type in a file beside one is
  never found: nest what a style needs as delegates inside it. No inline `component`, as
  everywhere in the shell.
- **The traps others have fallen in.** `left`, `right`, `top`, `bottom`, `baseline` and `focus`
  cannot be property names. `Row` and `Column` close up over a child with `visible: false`: hide
  a word that must keep its room with `opacity: 0`. A pooled slot changes line a frame before
  its inner delegates follow, so guard `line.words[j]` with `j < line.words.length`, or hand the
  delegates the word itself. A binding from `font.letterSpacing` to `font.pixelSize` is a loop:
  work from `size`.
- **Every colour is the cover's** (`Palette.js`), so each song looks like itself.
- **One family** (`Theme.lyricFont`), heavy for the words that carry a line and light for the
  ones that pass.

## Looking at one

```sh
tools/qs-verify/lyrics.sh up                                  # once: harness, player, song
tools/qs-verify/lyrics.sh sync                                # after every edit
tools/qs-verify/lyrics.sh frames /tmp/out Punch 38.3 41.0     # frames at moments of the song
tools/qs-verify/lyrics.sh strip /tmp/out Poster 12.4 13.6 12  # twelve frames as one sheet
tools/qs-verify/lyrics.sh fade /tmp/out 0.25 0.5 0.75         # the way in, held at three points
tools/qs-verify/lyrics.sh probe Drift 28                      # what a frame costs each thread
tools/qs-verify/lyrics.sh log                                 # what the shell warned of
tools/qs-verify/lyrics.sh down
```

`QS_VERIFY_WORK=/tmp/qsv-mine` gives a second harness beside another. `QS_SETTLE=1.6` gives a
busy machine longer between a pin and its capture. `down` removes the harness's whole folder, so
keep the pictures somewhere else. If the shell under test crashes, Quickshell starts it again by
itself with the files it had, and that copy would go on answering in place of the one a `sync`
starts: `log` says when there is a crash report, and `sync` puts any such copy down first. The
fixture song is in `tools/qs-verify/fixtures/lyrics-plus.json`; `tools/lyrics-test.mjs` checks
the parsing, the colours and the curves under node, and `nix flake check` runs it.
