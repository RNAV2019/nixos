# motion: a 120 Hz recorder and checker for the shell's animations

Proves animation changes the way `qs-verify` proves static ones: the shell runs in the headless
sway harness at **120 Hz**, scenarios drive the UI, and each run leaves a motion log and a video.

```sh
# TREE is a quickshell config dir. Output: OUT/<scenario>.log (and .mkv with QS_VIDEO=1)
QS_VIDEO=1 tools/qs-verify/motion/record.sh home/quickshell /tmp/m-new open-close abc retoggle
node tools/qs-verify/motion/check.mjs /tmp/m-new [--expect FILE] [--max-anim-ms N]
nix shell ... python tools/qs-verify/motion/video.py /tmp/m-new   # blank frames (see below)
nix run nixpkgs#nodejs -- --test 'tools/qs-verify/motion/*.test.mjs'   # check.mjs fixtures
```

`record.sh TREE OUT_DIR SCENARIO...` starts the harness (its own sway, buses and scratch HOME;
`QS_VERIFY_WORK`, default `/tmp/qsv-motion`) with `QS_THEME=ariadne QS_REFRESH=120 QS_MOTION_LOG=1`,
resets the UI before each scenario, and tears down at the end (`QS_KEEP=1` keeps it up). Scenarios:
`open-twice` (cold then warm open; with the `.marks` file `first h change` is toggle to first motion), `click-off-early` (a click 200 ms into an open dismisses), `click-through`. Others:
`satellite-hover-panel ping-pong ping-pong-slow open-close abc abc-slow retoggle-prepresent retoggle retoggle-fast subview subview-keys osd-over-open carousel controls satellite satellite-click lock-satellite lock-osd-satellite toast-stack dictation-levels launcher-scroll reduce`
(`all` = every one). `reduce` restarts the harness with `QUICKSHELL_REDUCE_MOTION=1` and records the
whole set into `OUT_DIR/reduce/`; check it with `check.mjs OUT_DIR/reduce --max-anim-ms 80`.

## 120 Hz: what worked

Headless sway accepts `output HEADLESS-1 mode 1920x1080@120Hz` directly (`swaymsg -t get_outputs`
reports 120000 mHz; `record.sh` prints it and warns otherwise), so no nested Hyprland was needed.
The compositor line lives in `run.sh` (not `lib.sh`): `QS_REFRESH` (default 60) sets the rate; the
`QS_*` scrub in run.sh is why it is read before the scrub. `run.sh` also passes `QS_MOTION_LOG` and
`QUICKSHELL_REDUCE_MOTION` into the shell's environment (env.sh) when set.

Video is `wf-recorder -D -r 120 -c libx264rgb crf=0` on the headless output: lossless, 120 fps
nominal (the mkv's average comes out a little higher, ~125, because frames are copied on a timer).
The pointer is in the capture. wf-recorder takes a second to start; `record.sh` waits 1 s before the
scenario so the first frame is the island at rest.

## The log and `check.mjs`

The shell (with `QS_MOTION_LOG=1`) prints `motion <label> <t_ms> <value> <velocity>
<target>` once per frame per running spring; `record.sh` keeps those lines. One label in one file is one spring. Rules (the
`RULES` table in `check.mjs`: add an entry and, if it needs an option, one line in `parseArgs`):

- **stepping**: a running spring (velocity not 0, not at target) whose value is unchanged between two
  consecutive frames.
- **overshoot**: value past its target in the direction of travel by more than 0.5% of the travel, the room `Theme.morphDamping` 0.9 needs to settle (segment = samples sharing a target,
  starting from the value where the target changed). Skipped for `phone.*`.
- **stall**: velocity 0 while the target still differs, for labels matched by `--expect FILE` (globs,
  one per line, `#` comments). The frame where the target changes and the last sample of a log are
  deliberate stops and not flagged.
- **static** (`--expect-static GLOB[,GLOB]`): a label that must not move while its surface's springs run,
  e.g. `surface.*.contentX` (where the contents sit on screen; logged only during a morph). Fails when the
  value changes by more than 0.01 inside one run of samples (less than 100 ms apart).
- **monotonic** (`--expect-monotonic GLOB[,GLOB]`): an opacity logged against its intent (`surface.<key>.body`:
  target 1 while the contents should be up, 0 while they should go). Within one run of samples sharing a
  target the value never turns back by more than the printed quantum; a re-toggle (new target) starts a new
  run. The first sample of a run is not judged: it can still carry the last frame of the previous intent.
- **fade-frames** (`--expect-fade-frames GLOB:N[,GLOB:N]`): an opacity that falls from 0.95 or more to 0.05 or less in fewer
  than N samples is a cut, not a fade (`surface.*.body:3` on the contents).
- **continuity** (`--expect-continuity GLOB[,GLOB]`, e.g. `surface.*.w,surface.*.h`; `expect-handover.txt` lists the same for the
  stall rule): a handover is read off the log as surface B's spring starting a run (first sample, or more than 100 ms after its
  previous) while another surface's spring on the same axis (`.w` or `.h`) logged a sample in the 250 ms before. That sample's
  velocity is what B must carry: when it is over 200 px/s, B's target lies the way it was heading and B's first velocity is under
  half of min(|v_out|, 21 x distance) (the clamp of `Motion.seedVelocity`), B started from rest. `abc` (60 ms apart) never gets a
  window on screen before the next claim, so `abc-slow` (100 ms, windows warmed first) is the scenario that exercises it, with
  `osd-over-open`. Fails on the parent of the momentum commit for both.
- **overshoot-tol** (`--overshoot-tol GLOB:PX[,GLOB:PX]`): lets matching labels run PX past a target. For springs retargeted ~30 times a second (`dict.bar*:0.25`), whose carried speed passes a target that lands just behind them.
- **anim-length** (`--max-anim-ms N` only): a segment that takes longer than N ms to reach its target.

Exit 1 with `<file>: <label>: <rule> at frame <n> (t=<ms>): <detail>` per failure.

## `video.py`: blank frames and islands

Counts frames where no pixel of row y = 12 (inside the island's top edge, x 460..1460) is near the
island colour taken from the first frame: a pill that vanishes between two surfaces is a blank frame.
Prints `<scenario>: <n> blank of <frames> frames (runs)`, then the island count: frames whose row has two or more
island-coloured components (gaps over 12 px; the still beside a smaller taker would show so) and width jumps over 50 px in one
frame. Jumps are noisy (a stalled frame is one; open-close has 2-3 on every build), so judge them against the parent's
capture, and read components as the hard bar (0 here). It needs numpy and ffmpeg:

```sh
PY=$(nix build --impure --no-link --print-out-paths --expr 'with import <nixpkgs> {}; python3.withPackages (p: [p.numpy])')
FF=$(nix build --no-link --print-out-paths nixpkgs#ffmpeg)   # (use --inputs-from the repo for the pin)
PATH=$FF/bin:$PATH $PY/bin/python tools/qs-verify/motion/video.py OUT_DIR
```

Verified with a synthetic clip (5 frames boxed out of a real capture): reports `5 blank (100-104)`.

## `video.py --satellite`

`video.py OUT_DIR --satellite` follows the phone satellite instead: per frame the right edge of the
silhouette on the disc's midline (x 700..1800, the run through the centre, runs under 30 px apart
being one) and the area of island-coloured pixels in the 44 columns before it. The recorder repeats and
drops frames, so steps between frames are not the spring's: repeated frames are skipped, and a pop is a
step more than 2.5 times both neighbouring steps and over 1.5 px (edge) or 2% of a full disc (area).
It also reads the OSD pill growing beside the disc and a lock covering the screen, so read the flags
by frame number against the scenario, and compare with the parent's capture. `satellite-click` drives
a click on the docked disc (log: `surface.phone.showing`).

## Baselines (main 8567e52, taken 2026-11-05)

- Screenshots: `~/.cache/qs-verify/baseline-motion-main` (82 PNGs + meta.txt). `sharing-connecting`
  never settled in that run (two identical frames not reached); treat that one state as unstable.
- Video: `~/.cache/qs-verify/motion-main/*.mkv`, blank frames in `blank-frames.txt` there:
  open-close 0/484, abc 0/537, retoggle 0/540, subview 0/786, satellite 0/1810. That is the bar:
  no scenario may get a blank frame.

## Traps

- `lock-satellite` drives `lockpreview preview true`: the rehearsal stage (an overlay window), not a
  session lock. The stage covers the bar, and the lock patches the satellite out of a capture it stands
  on, so it records the stage only. It still produces the log for whatever the shell emits.
- Calling `stop.sh` from a shell that has loaded the harness env finds its own children; `record.sh`
  uses `env -u XDG_RUNTIME_DIR`.
- Compare against a capture of the parent commit made in the same conditions (see memory
  `qs-verify-timing-and-motion`); the 120 Hz clock and wf-recorder add noise of a frame or two.

## What the log provides

- **Precision:** print the value with at least 4 decimals (velocity with 3 or more). `check.mjs`
  infers the printed quantum from the value's decimals and flags a repeated value as stepping only when
  the movement the velocity implies for that frame (|v| x dt) exceeds 3 quanta, so a converging tail at
  coarse precision is tolerated; the coarser the log, the less the stepping rule can see. At 2-3
  decimals the late tail goes unchecked. `--resolution Q` overrides the inferred quantum.
- **Labels:** one label is one spring. Per-instance springs (Repeater delegates, one per tile) need a
  unique label each (e.g. `tile.3.x`), or their samples interleave and every rule misfires.

## Shader smoke test

`shader-smoke.sh` loads `home/quickshell/Shaders/roundedclip.frag.qsb` in a real Qt scene graph
(headless sway, because the offscreen QPA plugin has no GL and falls back to the software
backend, where ShaderEffect does nothing) and checks the clip in two cases: item equal to the box,
and an item (200x160) larger than the box (100x60 at origin 40,50) so `itemSize` and `boxOrigin`
are exercised. Prints `PASS` or `FAIL <case> ...`. Frames go to a per-run temp dir that is removed.
The shader's uniforms: `boxSize`, `boxOrigin`, `itemSize` (all item px), `radius`, `aa`
(1/devicePixelRatio). Copy the pattern to smoke-test later shaders. A third case draws `hills.frag` with three half-transparent red layers and checks the RGB of the
bottom row (alpha 223, red 255 once un-premultiplied): a shader that multiplies the colour uniform by
its alpha again (Qt delivers it premultiplied) reads red 128 there. A fourth draws `lockglass.frag` with
everything but its see-through off (a blue backdrop behind digits inked in the top half only: blue there,
nothing below), a fifth `lockpatch.frag` (blue wallpaper inside the island, red capture outside it).

## Other scenarios

The `launcher-scroll` scenario adds twelve fixture apps matching one query and arrows through the list
(label `launcher.scroll`).

`nearby-switch` (Send <-> Receive by the arrow keys, frames in `OUT/nearby-switch-*.png`) and `lock-reveal` (the lock
preview's reveal in, then out through `qsipc lockpreview unlock`; log labels `lock.flight` and `lock.rise`,
0 with the clock in the pill and 1 with it mid-screen, and `lock.pill.w`, the pill's width in device px)
never touch the real lock.
