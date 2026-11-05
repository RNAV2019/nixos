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
`open-close abc retoggle subview osd-over-open segmented carousel satellite lock-satellite reduce`
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

The shell (from Task 1 on, with `QS_MOTION_LOG=1`) prints `motion <label> <t_ms> <value> <velocity>
<target>` once per frame per running spring; `record.sh` keeps those lines. Before Task 1 the logs are
empty (`check.mjs` then reports 0 samples, exit 0). One label in one file is one spring. Rules (the
`RULES` table in `check.mjs`: add an entry and, if it needs an option, one line in `parseArgs`):

- **stepping**: a running spring (velocity not 0, not at target) whose value is unchanged between two
  consecutive frames.
- **overshoot**: value past its target in the direction of travel (segment = samples sharing a target,
  starting from the value where the target changed). Skipped for `phone.*`.
- **stall**: velocity 0 while the target still differs, for labels matched by `--expect FILE` (globs,
  one per line, `#` comments). The frame where the target changes and the last sample of a log are
  deliberate stops and not flagged.
- **static** (`--expect-static GLOB[,GLOB]`): a label that must not move while its surface's springs run,
  e.g. `surface.*.contentX` (where the contents sit on screen; logged only during a morph). Fails when the
  value changes by more than 0.01 inside one run of samples (less than 100 ms apart).
- **anim-length** (`--max-anim-ms N` only): a segment that takes longer than N ms to reach its target.

Exit 1 with `<file>: <label>: <rule> at frame <n> (t=<ms>): <detail>` per failure.

## `video.py`: blank frames

Counts frames where no pixel of row y = 12 (inside the island's top edge, x 460..1460) is near the
island colour taken from the first frame: a pill that vanishes between two surfaces is a blank frame.
Prints `<scenario>: <n> blank of <frames> frames (runs)`. It needs numpy and ffmpeg:

```sh
PY=$(nix build --impure --no-link --print-out-paths --expr 'with import <nixpkgs> {}; python3.withPackages (p: [p.numpy])')
FF=$(nix build --no-link --print-out-paths nixpkgs#ffmpeg)   # (use --inputs-from the repo for the pin)
PATH=$FF/bin:$PATH $PY/bin/python tools/qs-verify/motion/video.py OUT_DIR
```

Verified with a synthetic clip (5 frames boxed out of a real capture): reports `5 blank (100-104)`.

## Baselines (main 8567e52, taken 2026-11-05)

- Screenshots: `~/.cache/qs-verify/baseline-motion-main` (82 PNGs + meta.txt). `sharing-connecting`
  never settled in that run (two identical frames not reached); treat that one state as unstable.
- Video: `~/.cache/qs-verify/motion-main/*.mkv`, blank frames in `blank-frames.txt` there:
  open-close 0/484, abc 0/537, retoggle 0/540, subview 0/786, satellite 0/1810. That is the bar:
  no scenario may get a blank frame.

## Traps

- `lock-satellite` drives `lockpreview preview true`; the headless harness shows no lock surface for it
  (see qs-verify README, "Lock screen"), so it records the satellite beside the clock only. It still
  produces the log for whatever the shell emits.
- Calling `stop.sh` from a shell that has loaded the harness env finds its own children; `record.sh`
  uses `env -u XDG_RUNTIME_DIR`.
- Compare against a capture of the parent commit made in the same conditions (see memory
  `qs-verify-timing-and-motion`); the 120 Hz clock and wf-recorder add noise of a frame or two.

## What Task 1's log must provide

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
(1/devicePixelRatio). Copy the pattern to smoke-test later shaders.
