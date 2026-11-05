# Shell Motion Fluidity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every animation in the Quickshell shell moves on every 120 Hz frame and costs constant
work per frame. Shape and contents move as one, and the phone satellite is redrawn on the GPU.

**Architecture:**
- The pure maths (spring step, handover velocity rule, progress, fade curves) moves into one
  `.pragma library` JS file, so node can unit-test it.
- Every spatial motion goes through `MorphSpring` (per-frame).
- The surface content is laid out once at its open size and clipped by a rounded-rect SDF shader.
- Content opacity is a pure function of shape progress.
- The satellite is one SDF fragment shader.
- Verification is three things: node unit tests for the maths, a per-frame motion log checked by a
  script in the 120 Hz headless harness, and the screenshot harness plus a video recorder for
  blank frames.

**Tech Stack:** Quickshell (Qt 6 QML) on Hyprland/sway headless, GLSL compiled with `qsb`
(nixpkgs `qt6.qtshadertools`), node (via `nix run nixpkgs#nodejs`), bash. Python (numpy/scipy) is
used for the video analysis.

**Spec:** `docs/superpowers/specs/2026-11-05-motion-fluidity-design.md`. Read it first; its
"Decided by Ryan" and "Calls made by Claude" sections are binding.

## Global Constraints

- Pace is unchanged: `Theme.morphOmega` stays 21.
- No overshoot on anything except the phone satellite, which keeps `phoneSpringOmega` 17 and
  `phoneSpringDamping` 0.7.
- `Theme.reduceMotion` must keep working. Every duration is a Theme token that goes through
  `Theme.duration()`.
- Colours come only from Theme tokens, with no literals.
- Every `.qml` passes `qmlformat` with `home/quickshell/.qmlformat.ini`
  (`nix build .#checks.x86_64-linux.quickshell-qmlformat`).
- New shared pieces go in `home/quickshell/Ui/`, with a header comment and an entry in
  `Ui/README.md`.
- Shaders live in `home/quickshell/Shaders/*.frag`. The compiled `*.frag.qsb` is committed beside
  each one, and `tools/qs-shaders.sh` regenerates them.
- Keep the presented-frame handover guarantee. A still stays up until its taker has a frame on
  screen.
- Never restart or reload Ryan's live shell. Test only in `tools/qs-verify` (headless sway) or in
  nested Hyprland.
- Harness runs always set `QS_THEME=ariadne` and a unique `QS_VERIFY_WORK`.
- All work happens in the worktree `~/nixos-motion` on branch `feat/motion-fluidity`. Each task
  is one or more commits, so any task can be reverted.

## Review Focus

1. **Rapid toggling.** Toggling the same panel, or A→B→A, within one morph must not freeze,
   flash bare wallpaper or leave a stale still. This is pinned by the `abc` and `retoggle`
   scenarios in Task 7.
2. **A transient pill arriving while a panel is mid-open,** and the reverse: rank and handover
   must still yield one clean shape. Pinned by the `osd-over-open` scenario in Task 7.
3. **Reduce motion.** `QUICKSHELL_REDUCE_MOTION=1` still snaps or shortens everything, including
   the new progress-driven fades and the satellite. Pinned by the `reduce` scenario in Task 12.
4. **A panel whose open size changes while open** (Nearby gaining peers, the control-centre
   sub-view, the phone Browse note): the fixed content box must follow the new open size without
   resampling. Pinned by the harness states `nearby-peers` and `phone-note` in Task 5.
5. **Lock while the satellite is moving.** The lock snapshot still waits on `Bus.lockHeld`.
   Pinned by the `lock-satellite` scenario in Task 11.

---

### Task 0: Worktree, baselines, 120 Hz motion harness

**Files:**
- Create: `tools/qs-verify/motion/record.sh`, `tools/qs-verify/motion/scenarios.sh`,
  `tools/qs-verify/motion/check.mjs`, `tools/qs-verify/motion/video.py`,
  `tools/qs-verify/motion/README.md`
- Modify: `tools/qs-verify/lib.sh` (headless output refresh from `QS_REFRESH`, default 60)

**Interfaces:**
- Produces:
  - `tools/qs-verify/motion/record.sh TREE OUT_DIR SCENARIO...` starts the harness on `TREE`
    with `QS_REFRESH=120 QS_MOTION_LOG=1`. For each scenario it writes
    `OUT_DIR/<scenario>.log` (the quickshell log lines matching `^motion `) and, with
    `QS_VIDEO=1`, `OUT_DIR/<scenario>.mkv`.
  - `node tools/qs-verify/motion/check.mjs OUT_DIR [--expect FILE]` parses log lines of the form
    `motion <label> <t_ms> <value> <velocity> <target>`. It exits non-zero and prints the label
    and frame for each failure:
    - **stepping:** a running spring whose value does not change between two consecutive frames;
    - **overshoot:** a value past its target in the direction of travel, for any label not
      prefixed `phone.`;
    - **stall:** for labels listed in `--expect`, velocity falling to 0 while the target still
      differs, except at a deliberate stop.
  - `video.py OUT_DIR` counts frames where the island silhouette at y≈8 is missing (blank
    frames). It comes from the recipe in memory `qs-verify-timing-and-motion`.
  - Scenarios in `scenarios.sh`, one bash function each, driven with `qsipc`, `keys`, `cursor`
    and `ph`: `open-close` (control), `abc` (control→calendar→nearby, 60 ms apart), `retoggle`
    (control toggled 3× 80 ms apart), `subview` (control → Wi-Fi → back), `osd-over-open`,
    `segmented`, `carousel` (theme picker arrows), `satellite` (`ph_up`, hover card, volume OSD,
    open phone panel, close), `lock-satellite`, `reduce` (the whole set with
    `QUICKSHELL_REDUCE_MOTION=1`, checked only for "no animation longer than 80 ms").

- [ ] **Step 1: Create the worktree.** Run
  `git -C ~/nixos worktree add ~/nixos-motion -b feat/motion-fluidity main`.
  Expected: the worktree is created. Copy the spec and plan in if they are uncommitted.
- [ ] **Step 2: Take the screenshot baseline of main.**

  ```sh
  QS_THEME=ariadne QS_VERIFY_WORK=/tmp/qsv-base tools/qs-verify/run.sh ~/nixos/home/quickshell \
    && QS_VERIFY_WORK=/tmp/qsv-base tools/qs-verify/shoot.sh ~/.cache/qs-verify/baseline-motion-main
  ```

  Run `stop.sh` afterwards. Expected: `meta.txt` and about 80 PNGs.
- [ ] **Step 3: Add `QS_REFRESH` to `lib.sh`'s sway output line** (`output * mode
  1920x1080@${QS_REFRESH:-60}Hz`). Confirm in the harness that `swaymsg -t get_outputs` reports
  120 Hz. If headless sway refuses 120 Hz, fall back to the nested Hyprland recipe in memory, and
  note which one worked in `motion/README.md`.
- [ ] **Step 4: Write `check.mjs` and a fixture test,** `tools/qs-verify/motion/check.test.mjs`
  (`node --test`). Cases:
  - a synthetic log of a spring stepping on alternate frames → reports `stepping`;
  - one that crosses its target → `overshoot`;
  - one whose velocity is 0 mid-travel → `stall`;
  - a clean critically-damped trace → exit 0.

  Run: `nix run nixpkgs#nodejs -- --test tools/qs-verify/motion/`. Expected: 4 pass.
- [ ] **Step 5: Write `record.sh`, `scenarios.sh` and `video.py`.** Main has no motion log yet,
  so before Task 1 merges, `record.sh` on main yields empty logs. Record video on main
  (`QS_VIDEO=1`) for `open-close abc retoggle subview satellite` into
  `~/.cache/qs-verify/motion-main/`, and run `video.py`. Expected: the blank-frame count for each
  scenario is printed. Keep these numbers as the bar.
- [ ] **Step 6: Commit** `tools/qs-verify` as `test(qs-verify): 120 Hz motion recorder, log checker
  and scenarios`.

### Task 1: Motion maths library, per-frame spring helpers, motion log

**Files:**
- Create: `home/quickshell/Ui/Motion.js`, `home/quickshell/Ui/ProgressSpring.qml`,
  `tools/qs-verify/motion/motion.test.mjs`
- Modify: `home/quickshell/Ui/MorphSpring.qml` (use `Motion.springStep`; add `label`, `kick`, log),
  `home/quickshell/Commons/Theme.qml` (tokens)

**Interfaces:**
- Produces (`Ui/Motion.js`, `.pragma library`, no QML imports):
  - `springStep(x, v, omega, zeta, dt) -> {x, v}`, where `x` is the displacement from target.
    This is the exact solution now inlined in `MorphSpring.step`, for both `zeta === 1` and
    `zeta < 1`.
  - `seedVelocity(from, target, v, omega) -> number`. It returns 0 if `v` points away from
    `target`; otherwise it returns `v` clamped so that `|v| <= omega * |target - from|`, the
    largest speed a critically damped spring can have without crossing its target.
  - `progress(fromW, fromH, toW, toH, w, h) -> number|NaN`. It measures progress along the axis
    with the larger travel, clamped to 0..1, and returns `NaN` when neither axis travels more
    than 0.5 px.
  - `ramp(p, start, end) -> number` is a smoothstep of `p` over `[start, end]`, clamped to 0..1.
  - `snap(v, ratio) -> number` returns `Math.round(v * ratio) / ratio`.
- Produces (`MorphSpring`):
  - The existing API is unchanged.
  - New: `property string label: ""`. When `Theme.motionLog` is set and `label` is not empty,
    every step prints `motion <label> <t_ms> <value> <velocity> <target>`.
  - New: `function kick(v)` sets `velocity = v` and starts the driver if the value is off its
    target.
  - The default `epsilon` becomes `0.3`.
- Produces `Ui/ProgressSpring.qml`: a `MorphSpring` with `epsilon: 0.001` and
  `omega: Theme.morphOmega`. It is used as `ProgressSpring { target: shown ? 1 : 0 }`.
- Produces in `Theme`:
  - `readonly property bool motionLog`, from env `QS_MOTION_LOG === "1"`;
  - `readonly property real microOmega`, chosen so a 0→1 step reaches 90% in about the time
    `MicroSpring` 5.0/0.6/0.8 does today (measure it in the harness and record the value in the
    comment, roughly 28–32).

- [ ] **Step 1: Write the failing tests** in `motion.test.mjs`. Load `Motion.js` by reading the
  file, stripping the `.pragma library` line, and evaluating it with `new Function`. Assertions:
  - `springStep(10, 0, 21, 1, 1/120)` is identical to the current MorphSpring formula; copy the
    expected numbers from running the old formula once.
  - Stepping 1/120 for 300 ms against 1/60 for 300 ms lands within 0.01 px.
  - Critically damped from (10, 0) never changes sign over 2 s.
  - `seedVelocity(0, 100, -50, 21) === 0`.
  - `seedVelocity(0, 100, 5000, 21) === 2100`.
  - `seedVelocity(0, 100, 300, 21) === 300`.
  - A spring seeded with `seedVelocity` output never overshoots, checked over random inputs.
  - `progress(40, 42, 520, 400, 280, 42)` is about 0.5.
  - `progress(520, 400, 520, 400, 520, 400)` is NaN.
  - `ramp(0.5, 0, 1) === 0.5`, and `ramp(-1, 0, 1) === 0`.
  - `snap(10.67, 1.3333334)` lands on a 0.75 multiple.
- [ ] **Step 2: Run the tests.** Run: `nix run nixpkgs#nodejs -- --test tools/qs-verify/motion/`.
  Expected: FAIL (`Motion.js` missing).
- [ ] **Step 3: Implement `Motion.js`.** Refactor `MorphSpring.step` to call
  `Motion.springStep`. Add `label`, `kick`, the log line (`console.info`, so the harness log
  captures it) and the epsilon change. Add `ProgressSpring.qml` and the Theme tokens.
- [ ] **Step 4: Label the surface springs.** In `IslandSurfaceBase.qml`, label `widthSpring` and
  `heightSpring` as `"surface." + key + ".w"` and `".h"`. Label the island's springs in
  `Bar/Island.qml` as `"island.w"` and `"island.h"`. Label the phone progress spring
  `"phone.p"`.
- [ ] **Step 5: Run the unit tests and the motion check.** Run the unit tests, then
  `record.sh ~/nixos-motion/home/quickshell /tmp/m1 open-close abc` and `check.mjs /tmp/m1`.
  Expected: the tests pass and the `surface.*` labels have no `stepping` or `overshoot`. A
  `stall` on `abc` is expected and recorded as the known failure that Task 7 fixes.
- [ ] **Step 6: Run the screenshot comparison.** Run the harness `shoot.sh` and `compare.sh`
  against `baseline-motion-main`. Expected: only the known timing artifacts listed in memory
  `qs-verify-timing-and-motion`.
- [ ] **Step 7: Commit** as `feat(ui): Motion.js maths, ProgressSpring, per-frame motion log`.

### Task 2: Shader toolchain

**Files:**
- Create: `tools/qs-shaders.sh`, `home/quickshell/Shaders/roundedclip.frag`,
  `home/quickshell/Shaders/roundedclip.frag.qsb`
- Modify: `flake.nix` (add a check `quickshell-shaders`)

**Interfaces:**
- Produces:
  - `tools/qs-shaders.sh [--check]` compiles every `home/quickshell/Shaders/*.frag` (and
    `*.vert`) with `qsb --qt6 -o <file>.qsb <file>`, using `nix shell nixpkgs#qt6.qtshadertools`.
    With `--check` it compiles to a temporary directory and `cmp`s each result against the
    committed file, exiting 1 and naming every stale one.
  - Flake check `quickshell-shaders` does the same in the sandbox with
    `pkgs.qt6.qtshadertools`.
  - `roundedclip.frag` uniforms, in the standard `qt_Matrix` / `qt_Opacity` buffer:
    - `vec2 boxSize`: the clip rectangle's size in item px;
    - `vec2 boxOrigin`: its top-left inside the source;
    - `float radius`;
    - `float aa`: the antialias width in item px, which is `1/devicePixelRatio`.

    Sampler: `source`. Alpha is `smoothstep(aa, -aa, sdRoundBox(...)) * texture.a`, premultiplied.

- [ ] **Step 1: Write the check first.** Run `tools/qs-shaders.sh --check` with `roundedclip.frag`
  present and no `.qsb`. Expected: exit 1, naming it as missing.
- [ ] **Step 2: Implement the script and the shader,** and generate the `.qsb`.
- [ ] **Step 3: Run the check.** Run `tools/qs-shaders.sh --check`. Expected: exit 0. Run
  `nix build .#checks.x86_64-linux.quickshell-shaders`. Expected: success. If the sandbox output is
  not byte-identical, compare `qsb --dump` text instead and note why in the script.
- [ ] **Step 4: Commit** as `build(quickshell): shader sources, committed qsb, regen script and
  check`.

### Task 3: Controls onto per-frame springs

**Files:**
- Modify: `home/quickshell/Ui/Segmented.qml`, `home/quickshell/Ui/Switch.qml`,
  `home/quickshell/Control/MediaCard.qml` (thumb scale), `home/quickshell/Bar/Widgets/Workspaces.qml`,
  `home/quickshell/Control/DisplaysView.qml`

**Interfaces:**
- Consumes: `MorphSpring` (with `label` and `kick`), `ProgressSpring`, `Theme.microOmega`.
- Pattern: drop the `Behavior on X { MicroSpring {} }`. Add
  `MorphSpring { id: xSpring; target: <logical>; omega: Theme.microOmega; animate: <the old
  Behavior.enabled> }` and bind `X: xSpring.value`.
- Specifics:
  - **Segmented:** the plate's x and width share `omega` and must reach rest on the same frame.
    Keep `animate: root.settled`.
  - **Switch knob:** `ProgressSpring { target: checked ? 1 : 0; omega: Theme.microOmega }`.
  - **Workspaces:** spring a private `property real pillW` and use it for `implicitWidth`. The
    dots are not separately animated while the pill width moves.
  - **DisplaysView:** one `MorphSpring` per x, y, w and h, all with the same omega.

- [ ] **Step 1: Label the new springs** (`seg.x`, `seg.w`, `switch`, `ws.w`, `disp.<name>.x` and so
  on). Run `record.sh … segmented subview` on the branch before the change. Expected:
  `check.mjs` reports nothing for these labels yet, because they do not exist. The failing
  evidence for this task is the old `stepping`, which is visible only through video. Record the
  `segmented` video at 120 Hz on the parent commit and count the frames on which the plate moves.
- [ ] **Step 2: Migrate the five files.**
- [ ] **Step 3: Check the motion.** Run `record.sh … segmented subview` and `check.mjs`.
  Expected: no `stepping` and no `overshoot` on the new labels. The video shows the plate moving
  on every frame, about twice the frame count of Step 1.
- [ ] **Step 4: Check the screenshots and format.** Run the screenshot compare against the parent
  commit's shots. Expected: identical at rest. Then run qmlformat.
- [ ] **Step 5: Commit** as `perf(ui): controls on per-frame springs`.

### Task 4: Sub-view slides and panel springs

**Files:**
- Create: `home/quickshell/Ui/SubviewSlide.qml`
- Modify: `home/quickshell/Control/ControlCenter.qml`, `home/quickshell/Nearby/NearbyPanel.qml`
  (sub-views and the tile row x), `home/quickshell/Phone/PhonePanel.qml`,
  `home/quickshell/Ui/ConfirmGrid.qml`, `home/quickshell/Ui/CarouselRow.qml`,
  `home/quickshell/Ui/Tile.qml`
- Delete: `home/quickshell/Ui/SurfaceSpring.qml`, `home/quickshell/Ui/MicroSpring.qml`, and their
  Theme tokens (`surfaceSpring*`, `micro{Spring,Damping,Mass,Epsilon}`)

**Interfaces:**
- Produces `Ui/SubviewSlide.qml`:
  - an `Item` with `property Item home`, `property Item sub`, `property bool subShown`,
    `property bool subReady` (default true; bind it to a `Loader.status === Loader.Ready`),
    `readonly property real progress`, `readonly property bool settled`, and
    `property real travel` (default `width`);
  - `home.x = -progress * travel` and `sub.x = (1 - progress) * travel`, from one
    `ProgressSpring { label: "subview" }` whose target is `subShown && subReady ? 1 : 0`;
  - a hidden view gets `visible: false` once `settled`.
- Behaviour: drill-in slides to the left, back slides to the right. A sub-view whose `Loader` is
  still loading holds the home view in place, because the spring target waits on `subReady`.
  Opacity does not cross-fade; the card clip hides the off-card side.
- Consumers:
  - **ControlCenter:** replace its two `SurfaceSpring` Behaviors and keep `unloadIfParked`,
    reading `!slide.settled`.
  - **Nearby, Phone and ConfirmGrid:** replace their paired `ContentFade` opacity sub-view switches.
  - **CarouselRow:** one `ProgressSpring`-style `MorphSpring` on the selection index. The rail x
    and each `Tile`'s carousel geometry derive from it; `Tile` loses its four geometry Behaviors.
    `Tile`'s `border.width` NumberAnimation becomes `Morph { duration: Theme.morphState }`.
  - **NearbyPanel tile row x:** a `MorphSpring`.

- [ ] **Step 1: Record the parent's video.** Record `subview` and `carousel` at 120 Hz on the
  parent commit, as the before-reference.
- [ ] **Step 2: Implement `SubviewSlide`** and migrate ControlCenter first. Run `record.sh … subview`
  and `check.mjs`. Expected: `subview` is clean, and the log shows the spring starting only after
  the Loader is ready.
- [ ] **Step 3: Migrate Nearby, Phone and ConfirmGrid.** Run the harness states for Nearby
  receive, the phone Browse note and the profiles confirm. Expected: identical at rest. Take
  manual frames mid-switch with the scenario helpers, which should show a slide, not a fade.
- [ ] **Step 4: Migrate CarouselRow and Tile, and the Nearby tile row.** Run
  `record.sh … carousel`. Expected: clean, and the tile edges and rail reach rest on the same frame.
- [ ] **Step 5: Delete SurfaceSpring and MicroSpring and their tokens.** Run
  `grep -rn "SurfaceSpring\|MicroSpring\|SpringAnimation" home/quickshell`. Expected: no hits
  outside comments explaining history; remove those comments too.
- [ ] **Step 6: Run the full screenshot compare and qmlformat.** Expected: identical at rest.
- [ ] **Step 7: Commit** in two commits: `feat(ui): SubviewSlide; sub-views slide in Nearby, Phone,
  ConfirmGrid` and `perf(ui): carousel and panel geometry on per-frame springs; retire
  SpringAnimation`.

### Task 5: Fixed content box and shader clip (the reveal)

**Files:**
- Modify: `home/quickshell/Ui/FrostedSurface.qml`, `home/quickshell/Ui/IslandSurfaceBase.qml`,
  `home/quickshell/Ui/Panel.qml` (only if it reads `surface.width` for layout),
  `home/quickshell/Osd/Osd.qml`, `home/quickshell/Nearby/SharingPill.qml`,
  `home/quickshell/Activities/Moments.qml`, `home/quickshell/Recorder/RecordingFailedPill.qml`,
  `home/quickshell/Dictation/DictationPill.qml`, `home/quickshell/Ui/README.md` (Surfaces section)

**Interfaces:**
- Consumes: `Shaders/roundedclip.frag.qsb` (Task 2) and `Motion.snap`.
- Produces in `FrostedSurface`:
  - `property real contentWidth` and `property real contentHeight`: the open size;
    `IslandSurfaceBase` sets them to the surface's target open size.
  - `contentHolder` becomes exactly `contentWidth × contentHeight`, at
    `x = snap((width - contentWidth) / 2)` and y = 0. It is clipped by a `ShaderEffect` using
    `roundedclip` over a `ShaderEffectSource { sourceItem: contentHolder; hideSource: true }`
    whose size never changes during a morph.
  - The `mask` item and the `MultiEffect` are removed.
  - The existing `snap()` stays public.
- Produces in `IslandSurfaceBase`: an exposed `readonly property Item content`, which is the
  fixed box contents are parented to. README rule change: contents lay out at the open size and
  are centred by the box. They never bind to `surface.width` or `surface.height`.
- Pill files: replace `x: (win.surface.width - width) / 2` with layout inside the fixed box.
  `DictationPill`'s row uses the open width, and the × button is pinned by layout, not by
  `surface.width`.

- [ ] **Step 1: Write the failing evidence.**
  - Add the motion log label `surface.<key>.contentX`, logging `contentHolder`'s x relative to
    the screen, and record `open-close` on the branch. Expected on the current code: contentX
    changes over the morph, which is the "rides the edge" bug. Add
    `--expect-static surface.*.contentX` to `check.mjs`; it fails when a static label changes
    while its surface's springs run. Add a fixture test for that to `check.test.mjs`.
  - Measure per-frame render time with `QSG_RENDER_TIMING=1` during `open-close` and save the
    numbers.
- [ ] **Step 2: Implement the fixed box and shader clip,** and move the five pills.
- [ ] **Step 3: Check the motion.** Run `record.sh … open-close abc osd-over-open` and `check.mjs
  --expect-static surface.*.contentX`. Expected: pass. Run `video.py` on `open-close` and `abc`.
  Expected: the blank-frame count is no worse than the Task 0 bar.
- [ ] **Step 4: Check the screenshots.** Run the full shoot and compare against Task 4's
  shots. Expected: identical, or a sub-pixel crispness change on text (inspect the diff images and
  list each changed state in the commit message). `nearby-peers` and `phone-note` must not show
  softness.
- [ ] **Step 5: Compare render time.** Repeat the `QSG_RENDER_TIMING` measurement. Expected:
  per-frame render time during open is lower than in Step 1. Put both numbers in the commit
  message.
- [ ] **Step 6: Commit** as `perf(ui): fixed-size surface content with SDF clip; contents are
  uncovered, not slid`.

### Task 6: One clock for shape and contents

**Files:**
- Modify: `home/quickshell/Ui/IslandSurfaceBase.qml` (`bodyHolder`), `home/quickshell/Ui/CollapsedPill.qml`,
  `home/quickshell/Commons/Theme.qml` (fade thresholds as tokens; retire `morphContent`,
  `morphEnter` and `morphEnterDelay` if they become unused)

**Interfaces:**
- Consumes: `Motion.progress` and `Motion.ramp`.
- Produces in `IslandSurfaceBase`:
  - `readonly property real morphProgress`. It is `Motion.progress(fromW, fromH, toW, toH,
    width, height)`, where `from` is re-based to the current shape on every retarget. When that
    is `NaN`, it comes from a fallback `ProgressSpring { label: "surface.<key>.p" }`.
  - `bodyHolder.opacity` is a function of `morphProgress` with no Behavior. Tokens:
    - `Theme.fadeOpenIn: [0.0, 0.18]`: out of the pill, about as quick as today's 50 ms;
    - `Theme.fadeEnterIn: [0.25, 0.6]`: panel to panel, replacing the 45 ms delay and the 90 ms
      fade;
    - `Theme.fadeCloseOut: [0.0, 0.15]`.
  - These are starting values; tune them on video so they read like today.
  - `Translate.y` stays `(1 - opacity) * enterTravel`.
  - Monotonic rule from the spec: on a retarget, opacity is carried and only moves toward its
    new end.
- Produces in `CollapsedPill`: on close, `shown` opacity is the ramp of the closing surface's
  progress over `Theme.fadePillIn: [0.7, 1.0]`, instead of the 50 ms `ContentFade`.

- [ ] **Step 1: Write the failing evidence.** Log `surface.<key>.body` (opacity) and add the check
  `--expect-monotonic surface.*.body` to `check.mjs`, with a fixture test. It fails when opacity
  reverses direction within one open or close. Record `retoggle` on the branch. Expected: it fails
  on the current Behavior, because the restart jumps.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Check the motion.** Run `record.sh … open-close abc retoggle` and `check.mjs` with
  the monotonic check. Expected: pass. Watch the `open-close` and `abc` videos side by side with
  the Task 0 recordings, and tune the thresholds until content arrives no later than today
  (frame-count it).
- [ ] **Step 4: Run the screenshot compare.** Expected: identical at rest.
- [ ] **Step 5: Commit** as `feat(ui): content fades ride the shape's progress`.

### Task 7: Momentum through handover

**Files:**
- Modify: `home/quickshell/Ui/IslandOrigin.qml` (`hold`, `heldRadius`),
  `home/quickshell/Commons/Bus.qml` (`publishHandoff` at about line 368 and the claim record),
  `home/quickshell/Ui/IslandSurfaceBase.qml` (springs at about lines 212–225)

**Interfaces:**
- Consumes: `MorphSpring.kick` and `Motion.seedVelocity`.
- Produces:
  - `Bus.publishHandoff(screen, width, height, radius, vw, vh)`; the claim object gains `vw` and
    `vh`.
  - `IslandOrigin.hold(width, height, radius, vw, vh)`: the still's springs keep `animate` and
    retarget to the claim's shape, carrying the given velocity. `snapping` no longer zeroes
    velocity for a hold.
  - The held radius rides a `MorphSpring` (label `surface.<key>.r`).
  - The taker, on taking a claim, does
    `widthSpring.kick(Motion.seedVelocity(from.w, target.w, claim.vw, Theme.morphOmega))`, and the
    same for height.
  - The presented-frame wait is unchanged. The still stays until `takerPresented`.

- [ ] **Step 1: Confirm the stall.** Run `record.sh … abc retoggle osd-over-open` and `check.mjs
  --expect expect-handover.txt`. That file lists `surface.*.w` and `surface.*.h` under the stall
  rule. Expected: FAIL (`stall`) on `abc`, as recorded in Task 1.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Check the motion.** Run the same command. Expected: no `stall` and no
  `overshoot`. Run `video.py` on `abc`, `retoggle` and `osd-over-open`. Expected: the blank-frame
  count is no worse than the Task 0 bar, and no frame shows two islands (the still and the taker
  at different sizes) for more than 1 frame.
- [ ] **Step 4: Run the screenshot compare.** Expected: identical.
- [ ] **Step 5: Commit** as `feat(ui): panel handover carries the shape's velocity`.

### Task 8: Warm windows, settle tail, input regions

**Files:**
- Modify: `home/quickshell/Ui/IslandSurfaceBase.qml` (`retained`, park, mask),
  `home/quickshell/Ui/TransientSurface.qml` (`cardMask`), `home/quickshell/Commons/Theme.qml`
  (`surfaceWarmStagger`, and `surfaceRetain` if raised), `home/quickshell/Commons/Bus.qml` (only
  if warm-up needs a session-ready signal it does not already have)

**Interfaces:**
- Produces:
  - After the session is ready, each registered island surface sets `retained = true` in turn,
    `Theme.surfaceWarmStagger` (150 ms) apart. That presents one frame while parked. A warmed
    surface obeys `surfaceRetain` like any other.
  - `openMask` and `cardMask` use the *target* shape (open width, height and radius, centred and
    snapped) from the first frame of an open, not `Region { item: surface }`. At rest this must
    be identical to today.
  - The `MorphSpring` epsilon of 0.3 is already in from Task 1. Check here that windows stop
    rendering early. Log `surface.<key>.showing` transitions and compare the time from the last
    visible change to `showing=false` before and after.

- [ ] **Step 1: Measure the baseline.** Record `open-close` on a fresh harness (a cold first
  open). In the motion log, measure the time from the ipc toggle to the first `surface.control.h`
  change. Expected now: about 250 ms.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Measure again.** Expected: the cold-open delay matches a warm open (under 40 ms).
  RSS after warm-up (`ps -o rss` of quickshell) is no more than 30 MB above main; report the
  number.
- [ ] **Step 4: Check input.** Run the harness interaction checks: click off a card while it is
  opening dismisses it (add this to `scenarios.sh` as `click-off-early`), and clicks pass through
  transients with `cardInput: false`. Expected: both behave as at rest.
- [ ] **Step 5: Run the screenshot compare and commit** as `perf(ui): warm surfaces at start,
  target-shape input regions`.

### Task 9: Pill and in-panel choreography

**Files:**
- Modify: `home/quickshell/Activities/Moments.qml` (`swap`), `home/quickshell/Notifications/Toast.qml`,
  `home/quickshell/Notifications/Notifications.qml`, `home/quickshell/Control/WifiView.qml`
  (password row), `home/quickshell/Dictation/DictationPill.qml` (bars)

**Interfaces:**
- Consumes: `ProgressSpring`, `MorphSpring`, `Motion.ramp`.
- Specifics:
  - **Moments:** the stage opacity is a `ProgressSpring`. The content swap happens when opacity
    reaches 0, and the stage fades in after the swap; an interruption retargets the spring.
  - **Toast:** opacity is derived from the `riseSpring` progress. Exit is faster than enter
    (`Motion.ramp` over the first 0.6 of the travel when leaving).
  - **WifiView password row:** the height rides a `MorphSpring`. The content stays 40 px tall
    inside a clip.
  - **Dictation bars:** each bar height is a `MorphSpring` with `omega: Theme.levelOmega` (new
    token, about 40), replacing the 60 ms NumberAnimation.

- [ ] **Step 1: Record the before-video** of the harness states for moments, toasts, dictation
  and Wi-Fi password, through scenario helpers `moment-swap`, `toast-stack`, `dictation-levels`
  and `wifi-pass` (add them).
- [ ] **Step 2: Implement.** Label the springs `moment`, `toast`, `wifi.pass` and `dict.bar<N>`.
- [ ] **Step 3: Check the motion.** Run `check.mjs`. Expected: clean. `dict.bar*` must show
  settling, meaning velocity reaches below epsilon between level updates when the level is
  steady.
- [ ] **Step 4: Run the screenshot compare and commit** as `feat(ui): moments, toasts, dictation and
  Wi-Fi rows move on springs`.

### Task 10: Per-frame waste in widgets

**Files:**
- Create: `home/quickshell/Shaders/hills.frag` and `.qsb`
- Modify: `home/quickshell/Control/MediaCard.qml` (hills), `home/quickshell/Bar/Widgets/MiniCalendar.qml`,
  `home/quickshell/Ui/ScrollView.qml`, `home/quickshell/Launcher/Launcher.qml` (scroll only; the
  rows' fade-in stays), `home/quickshell/Phone/PhonePanel.qml:347`,
  `home/quickshell/Nearby/NearbyPanel.qml` (hard-coded durations), `home/quickshell/Ui/LoginPill.qml`,
  `home/quickshell/Commons/Theme.qml`

**Interfaces:**
- Produces:
  - `hills.frag`, a `ShaderEffect` with uniforms `phase`, `amplitude`, the three layer colours
    from Theme, and `progress`. It must look the same as the Canvas version; compare a still
    frame at the same phase.
  - **MiniCalendar:** a fixed `font.pixelSize` with `scale` animated.
  - **ScrollView:** the thumb binds directly, with no Behavior.
  - **Launcher:** `contentY` rides a `MorphSpring` (label `launcher.scroll`).
  - Every hard-coded duration becomes a named Theme token through `Theme.duration()`.

- [ ] **Step 1: Find the leftover durations.** Run
  `grep -rnE "duration: [0-9]+" home/quickshell --include=*.qml`. Expected: only the files above.
  Afterwards it must return nothing.
- [ ] **Step 2: Measure the Canvas cost.** With `QSG_RENDER_TIMING=1`, open the control centre
  with media playing (the harness has an MPRIS stub, or add one) and save the per-frame time.
- [ ] **Step 3: Implement,** and regenerate shaders with `tools/qs-shaders.sh`.
- [ ] **Step 4: Measure again and compare.** Expected: per-frame time is lower, and the harness
  media state is visually identical. Hills are masked if they are animated, so compare a manual
  still at a fixed phase.
- [ ] **Step 5: Check.** Run `tools/qs-shaders.sh --check`, the full screenshot compare and
  `check.mjs` on a `launcher-scroll` scenario (add it).
- [ ] **Step 6: Commit** as `perf(ui): GPU media hills, no per-frame relayout in calendar and scroll`.

### Task 11: Phone satellite on one SDF shader

**Files:**
- Create: `home/quickshell/Shaders/satellite.frag` and `.qsb`, `home/quickshell/Bar/SatelliteShape.qml`
- Modify: `home/quickshell/Bar/PhoneSatellite.qml`, `home/quickshell/Bar/Bar.qml` (input region),
  `home/quickshell/Bar/Island.qml` (expose the unsnapped edge), `home/quickshell/Ui/TransientSurface.qml`
  (hosts a `SatelliteShape` while followed), `home/quickshell/Commons/Bus.qml` (per-screen
  satellite geometry)

**Interfaces:**
- Produces:
  - In `satellite.frag`, all values in item px:
    - uniforms: `pillEdge` (vec2: the x of the pill's right edge and its midline y),
      `pillHalfH`, `capRadius`, `disc` (vec3: cx, cy, r), `neck` (the smooth-min k, from `p` and
      the gap), `outlineWidth`, `fill`, `outline`, `aa`;
    - the SDF is the smooth union of the pill's right cap and the disc. Stubs come from `neck`
      continuously, with no separate stub geometry.
  - `SatelliteShape.qml`: a `ShaderEffect` sized to the bud's bounds plus `aa`, with the same
    properties as the uniforms. It is used by both the bar and a following transient.
  - `Island` exposes `readonly property real edgeX`, which is
    `(W + widthSpring.value) / 2 + pillOffset`, unsnapped.
  - `Bus.satellite[screen] = { edgeX, midY, halfH, capR, disc, neck, follow }`, written by
    `PhoneSatellite` each frame while it moves.
  - `PhoneSatellite` keeps `edge + f(p)`, the ζ 0.7 spring (`phone.p`), `wantOut`, `settling`,
    `Bus.lockHeld` and the retreat for panels. It changes these:
    - the follow-target swap is blended. A `MorphSpring` (label `phone.blend`) carries the jump
      in edge, top, height and cap radius to 0;
    - the disc centre is snapped with `Motion.snap` only when `!progress.running`, and the
      snapped and unsnapped positions blend over the last 0.3 px of motion;
    - `Bus.toggleSurface("phone")` is moved into `Qt.callLater`;
    - the `nub` NumberAnimation, the `attached` and `inside` thresholds and the `PathSvg` paths
      are deleted.
  - Bar input region: a fixed rectangle at the docked position, applied only while `docked` and
    not moving.
  - The bud is drawn by the bar while it follows the pill or hover card, and by the transient
    while it follows a transient. A one-frame overlap at the switch is allowed; a gap is not.

- [ ] **Step 1: Record the before-video.** Record `satellite` and `lock-satellite` video on the
  parent commit. Use `video.py --satellite` (add it), which tracks the disc's area and centre per
  frame and flags any frame-to-frame area jump over 2% or centre jump over 1.5 device px that the
  spring cannot explain. Expected: it flags the attach and detach pops.
- [ ] **Step 2: Write the shader and `SatelliteShape`,** and regenerate the qsb. Check a still
  render of the docked state against the harness baseline `satellite-docked`. Expected: no change
  beyond antialiasing (inspect the diff).
- [ ] **Step 3: Rewrite the `PhoneSatellite` geometry** and the blend, and add the transient
  hosting.
- [ ] **Step 4: Check the motion.** Run `record.sh … satellite lock-satellite`, `check.mjs` and
  `video.py --satellite`. Expected: no flags. The `phone.p` label is allowed to overshoot, by
  prefix. The lock snapshot in `lock-satellite` is taken only after `settling` is false.
- [ ] **Step 5: Run the full screenshot compare** and review the phone states by eye. The
  satellite is redrawn on purpose, so list the changed states in the commit message.
- [ ] **Step 6: Commit** as `feat(phone): satellite drawn as one SDF metaball, blended follow, above
  transients`.

### Task 12: Reduce-motion pass, docs, final verification

**Files:**
- Modify: `home/quickshell/Ui/README.md` ("Motion and colour"), `tools/qs-verify/README.md`
  (the motion section), `tools/qs-verify/motion/README.md`

**Interfaces:**
- README "Motion and colour" now lists:
  - `MorphSpring` (label, kick, epsilon);
  - `ProgressSpring`;
  - `SubviewSlide`;
  - `Motion.js`;
  - the fixed content box rule;
  - the progress-driven fade tokens;
  - the shaders and `tools/qs-shaders.sh`.

  `SurfaceSpring` and `MicroSpring` are gone from it.

- [ ] **Step 1: Run the reduce-motion scenario.** Run `record.sh … reduce`. Expected: no motion
  label runs longer than 80 ms, and the satellite snaps. Fix any offender in the task that owns it.
- [ ] **Step 2: Run the full verification.**
  - `node --test tools/qs-verify/motion/`
  - `tools/qs-shaders.sh --check`
  - `nix build .#checks.x86_64-linux.quickshell-qmlformat .#checks.x86_64-linux.quickshell-shaders`
  - `record.sh` with every scenario, then `check.mjs`
  - `video.py` on all scenarios against the Task 0 bar
  - a full screenshot compare against `baseline-motion-main`, with every changed state listed
    and justified

  Expected: everything passes.
- [ ] **Step 3: Update the READMEs.** Add a memory file `motion-fluidity.md` that records what
  changed, the harness commands, and the numbers (render times, cold-open delay, RSS).
- [ ] **Step 4: Commit** as `docs(ui): motion primitives and harness`.
- [ ] **Step 5: Hand to Ryan for the A/B on the real machine.** Give the restart instructions
  (Ryan restarts quickshell outside T3, on the branch's worktree linked in). Do not merge until
  Ryan approves.
