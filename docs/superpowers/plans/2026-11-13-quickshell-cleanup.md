# Quickshell Clean-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the shell's numbers on shared scales, give every repeated pattern one home, remove dead code and excess comments, and fix the audited bugs, without changing how anything moves.

**Architecture:** Six phases in one worktree, each one kind of change so the screenshot harness can prove it: fixes, tokens, shared pieces, feature files, services, comments and docs. Pixel-identical phases must compare equal to a baseline; snap phases show only their listed snaps. Main is fast-forwarded once per phase after the check, and Ryan restarts and uses the shell before the next phase.

**Tech Stack:** QML (Qt 6, Quickshell 0.3.2), JavaScript helpers, GLSL (`.frag` + committed `.qsb`), `tools/qs-verify` (headless sway screenshot and motion harness), Nix flake checks, node for scripted edits and JS tests.

**Spec:** `docs/superpowers/specs/2026-11-13-quickshell-cleanup-design.md`. Audit reports with per-file findings and line numbers: `~/.cache/qs-audit/01..08-*.md`, `tokens.tsv`, `03-literals.tsv`, scripts in `~/.cache/qs-audit/scratch-03-theme-tokens/`. Line numbers in the reports are from commit 5ec30b5; find the code by name when they have moved.

## Global Constraints

- All work happens in `/home/ryan/nixos-cleanup`, branch `refactor/cleanup`. Never edit `/home/ryan/nixos` (the live shell runs from it and hot-reloads on every write). Never start, stop or restart the live shell.
- No change of feel: no duration, spring rate, damping, easing or choreography changes value.
- A snap lands only if nothing drawn moves or resizes by more than 2 px after derivations and stacked gaps are followed through, and no control's proportions change. `switchInset` stays 3, `launcherRowGap` stays 3, `launcherInset` stays 14.
- Not snapped: media titles 19, launcher answer 24, glyphs 12 and 22, `dictationRadius` 24, any 2 px spacing move.
- The lock clock's look must not change: texture sizes, sample counts, formats and `Shaders/lockglass.frag` are untouched.
- Relay files (`Ui/MorphScan.js`, `MorphLayer`, `MorphGhost`, `MorphPart`, `MorphMask`, `IslandOrigin`, `IslandSurfaceBase`, `IslandSurface`, `TransientSurface`, `CollapsedPill`, `IslandClock`, `SatelliteLayer`, the handoff parts of `Commons/Bus.qml`) take only: dead-code removal, listed bug fixes, few-line mechanical changes a rename or shared piece forces. No splits, no restructuring, no comment pass.
- No inline `component`. A new type is a file; shared by two features means `Ui/`.
- No abstraction with one caller; no shared piece with more flags than it saves. A shared piece reproduces each site's motion as it is today behind at most one property, or it waits for project 2.
- Comments: keep the why and the traps; a one-line purpose at the top of each file; no restating, no history, no dates or names.
- 2-space `qmlformat`. No python3 on PATH: bash, awk, or `nix run nixpkgs#nodejs`.
- Commit messages follow the repo's style (`refactor(quickshell): ...`, `fix(...)`), one commit per step that says "Commit".

### Verification recipes (referred to by name in the tasks)

**CHECKS** (every task):
```sh
cd /home/ryan/nixos-cleanup
nix build .#checks.x86_64-linux.quickshell-qmlformat .#checks.x86_64-linux.quickshell-shaders; echo "exit $?"
```
Expected: `exit 0`.

**STATIC `<name>`** (runs are strictly serial; they share one work dir so path text matches):
```sh
cd /home/ryan/nixos-cleanup
export QS_THEME=ariadne QS_VERIFY_WORK=/tmp/qsv-cleanup
tools/qs-verify/stop.sh; tools/qs-verify/run.sh home/quickshell; echo "run exit $?"
tools/qs-verify/shoot.sh /tmp/qsv-shots/<name>
tools/qs-verify/compare.sh "$(cat ~/.cache/qs-verify/cleanup-baseline)" /tmp/qsv-shots/<name> tools/qs-verify/allowed-cleanup.txt; echo "compare exit $?"
grep -c WARN /tmp/qsv-cleanup/quickshell.log
tools/qs-verify/stop.sh
```
Expected: `run exit 0`, `compare exit 0` with no differing state outside `allowed-cleanup.txt`, and a WARN count no higher than the baseline's (`~/.cache/qs-verify/cleanup-baseline-warns`). A differing state is a failure to investigate, never one to add to the allow file, unless the task says it changes pixels.

**MOTION `<name>`** (end of each phase):
```sh
cd /home/ryan/nixos-cleanup
QS_VERIFY_WORK=/tmp/qsv-cleanup-motion tools/qs-verify/motion/record.sh home/quickshell /tmp/qsv-motion/<name> all
nix run nixpkgs#nodejs -- tools/qs-verify/motion/check.mjs /tmp/qsv-motion/<name> --expect tools/qs-verify/motion/expect-handover.txt > /tmp/qsv-motion/<name>.txt; diff ~/.cache/qs-verify/cleanup-motion-baseline.txt /tmp/qsv-motion/<name>.txt
```
Expected: the set of rule failures equals the baseline's (the baseline already fails `retoggle-prepresent` monotonic). Record the lock scenarios in a run of their own, last.

**JS `<file>`**: `nix run nixpkgs#nodejs -- --test 'tools/qs-verify/js/*.test.mjs'`, expected all pass.

**PHASE GATE** (end of each phase; done by the session lead, not a task worker): STATIC, MOTION, CHECKS; a fresh reviewer reads the phase's diff against the spec; `git -C /home/ryan/nixos merge --ff-only refactor/cleanup`; tell Ryan to restart the shell outside T3 Code and list what the harness could not show; on a snap phase the approved capture becomes the new baseline (`echo <dir> > ~/.cache/qs-verify/cleanup-baseline`).

## Review Focus

1. **Theme switch at run time.** After `Theme` splits, a `theme-switch` must still recolour every surface; `Metrics` and `Timing` hold no colours. Test in Task 9.
2. **Reduce motion.** With `QUICKSHELL_REDUCE_MOTION=1` no label runs past 80 ms after `Timing.ms()` becomes the only door. Test in Task 11.
3. **Fractional scale 1.25.** Ryan's display runs at 1.25 and the baseline is taken at 1. Snaps and `Label` must not blur or shift by a device pixel there. Test in Tasks 12 and 13.
4. **A daemon or file missing at start.** `Query`, `WatchedFile` and lazy providers must log and recover when a command is absent or exits non-zero, not hang a queue. Test in Tasks 27 and 29.
5. **Two outputs.** Shared singletons (`MinuteClock`) and per-screen `Variants` must behave with a second output; the harness gains one in Task 2. Test in Tasks 2 and 16.

---

## Phase 0: baseline and fixes

### Task 1: Worktree and baselines

**Files:** Create: `tools/qs-verify/allowed-cleanup.txt`.

- [ ] **Step 1:** `git -C /home/ryan/nixos worktree add /home/ryan/nixos-cleanup -b refactor/cleanup` and confirm `git -C /home/ryan/nixos-cleanup log -1 --format=%h` equals main's.
- [ ] **Step 2:** Run the STATIC commands twice with output dirs `~/.cache/qs-verify/cleanup-base-a` and `/tmp/qsv-shots/base-b`, skipping the compare line. Compare b against a. Every state that differs between two runs of the same tree is noise: write each to `tools/qs-verify/allowed-cleanup.txt` in `compare.sh`'s allow format with a one-line reason.
- [ ] **Step 3:** `echo ~/.cache/qs-verify/cleanup-base-a > ~/.cache/qs-verify/cleanup-baseline`; write the WARN count to `~/.cache/qs-verify/cleanup-baseline-warns`.
- [ ] **Step 4:** Run MOTION with name `base`, skipping the diff; copy its `.txt` to `~/.cache/qs-verify/cleanup-motion-baseline.txt`.
- [ ] **Step 5:** Commit `allowed-cleanup.txt`.

### Task 2: Widen the harness

**Files:** Modify: `tools/qs-verify/shoot.sh`, `lib.sh`, `run.sh`, `masks.txt`, `README.md`. Create fixtures under `tools/qs-verify/fixtures/` as needed.

**Interfaces:** Produces new state names later tasks rely on: `lock-preview`, `lock-preview-password`, `lock-preview-refuse`, `picker-files`, `picker-images`, `nearby-send-staged`, `launcher-clipboard`, `launcher-emoji`, `displays-two`.

- [ ] **Step 1:** Add the lock states through the `lockpreview` ipc: `background PREFIX` on a fixed generated wallpaper capture, `time 09:41`, then `preview`, `password`, `refuse`. Shoot them last (a lock scenario leaks into later states).
- [ ] **Step 2:** Add `picker-files` and `picker-images` (Nearby's "choose files" and the phone wallpaper picker, over a fixture directory with three text files, two images, one folder), `nearby-send-staged` (two files staged with a peer present), `launcher-clipboard` and `launcher-emoji` (a stub `cliphist` on PATH printing five fixed entries; the scope opened by its chip).
- [ ] **Step 3:** Add `displays-two`: start sway with a second headless output (`swaymsg create_output`) for that state only and remove it after; capture the control centre's Displays view.
- [ ] **Step 4:** Run the harness against the unmodified `home/quickshell` twice; each new state must settle and compare equal between the two runs, or be masked with a reason. Then re-take the baseline (Task 1 steps 2 to 3) so it includes the new states.
- [ ] **Step 5:** Update `tools/qs-verify/README.md` (covered and not-covered lists). CHECKS. Commit.

### Task 3: Revive the burn-in orbit

**Files:** Modify: `home/quickshell/shell.qml`, `tools/qs-verify/run.sh`, `tools/qs-verify/shoot.sh`. Read: `Services/OledCare.qml`, `Commons/Bus.qml` (`pillShift*`, `workspacesOffset*`).

- [ ] **Step 1:** Add a harness check (not a screenshot) `oled-orbit`: with `QS_OLED_INTERVAL_MS=300` passed through `run.sh` in place of the huge patched interval, read the pill's x from two `grim` crops 1 s apart and fail if they are equal. Run it; expected: FAIL (the singleton is never created).
- [ ] **Step 2:** Reference `OledCare` from `shell.qml` so the singleton is instantiated at start (a one-line `readonly property var oledCare: OledCare` beside the other service anchors, or the form `shell.qml` already uses for one).
- [ ] **Step 3:** Run `oled-orbit`; expected: PASS. Check the pill, the workspaces pill, a panel opened while shifted, and `lock-preview` all sit on the shifted position (crop compare). Fix an offset bug in the bar or lock; in a relay file fix it only if it is a few lines, otherwise write it to `~/.cache/qs-audit/cleanup-notes.md`.
- [ ] **Step 4:** STATIC `t3` (the default run keeps the interval huge, so it must be identical). CHECKS. Commit.

### Task 4: Dead code

**Files:** Modify across the tree; the lists are in reports 01 (finding 7), 03 (section 6), 04 ("Dead API"), 06, 07, 08 (findings 5, 7 and 10).

- [ ] **Step 1:** For each item, grep `home/quickshell`, `tools/qs-verify`, `home/` and `modules/` (ipc names appear in Nix, Lua and fish) for a reader. Remove only what has none: the `Bus` members `islandHeld`, `islandHeldFor`, `islandTaken`, `transientKeys`; `pillSlideX` only if nothing writes it with `OledCare` running; `FrostedSurface.screenOffsetX/Y` and its two writers; `Island.settled`; `CollapsedPill.clockShift`; Theme's `liftSelected`, `mediaSkipSize`, `nearbyChosenRadius`, `recorderRowRadius`, `surfaceBlur`, `surfaceSubtle`, `highlightLow`; the unused properties, variants and signals on the primitives; every `morphSlot` declaration and the `morphKey: ""` defaults nobody overrides; the ten unused icon names; `lastDir`; `Control/Util.qml` (its one function becomes `Array.filter` at the call site); the providers' `matches`/`positions` and `Fuzzy`'s backtrack; `Button.Danger`; the `activities charger` ipc; unused imports and ids.
- [ ] **Step 2:** STATIC `t4`, CHECKS. Commit.

### Task 5: Shader early-outs

**Files:** Modify: `home/quickshell/Shaders/shadow.frag`, `roundedclip.frag`; regenerate `.qsb` with `tools/qs-shaders.sh`.

- [ ] **Step 1:** `shadow.frag`: compute `inside` first and return a transparent pixel when it is 1, before the Gaussian. `roundedclip.frag`: return when the box coverage `a` is 0, before the blur taps.
- [ ] **Step 2:** `tools/qs-shaders.sh`, then `tools/qs-verify/motion/shader-smoke.sh`; expected: every case passes.
- [ ] **Step 3:** STATIC `t5` (must be identical), CHECKS. Commit.

### Task 6: Bugs in Control, Calendar and Media

**Files:** Modify: `Control/WifiView.qml`, `BluetoothView.qml`, `Calendar/CalendarPanel.qml`, `Services/Calendar.qml`, `Ui/MediaScrub.qml`. Evidence: report 05 "Likely bugs", report 04 (`MediaScrub.nudge`).

- [ ] **Step 1:** Reproduce each by reading or in the harness, and write one line per bug to `~/.cache/qs-audit/cleanup-notes.md` (reproduced / not reproduced, how). Fix only the reproduced: Rescan a no-op while the view is open; Wi-Fi `pendingSsid` stranding so Back needs two presses; calendar "today" stale past midnight (derive from a date that changes at midnight); the per-cell event scan (build one day map per month); `MediaScrub.nudge` seeking NaN on length 0 (guard).
- [ ] **Step 2:** For the calendar day map add `tools/qs-verify/js/calendar.test.mjs` if the map is built in a `.js` helper: events on a day, all-day first, month boundaries. JS.
- [ ] **Step 3:** STATIC `t6`, CHECKS. Commit.

### Task 7: Bugs in Nearby, Phone and small items

**Files:** Modify: `Nearby/NearbyPanel.qml`, `Nearby/SharingPill.qml`, `Nearby/DeviceTile.qml`, `Bar/Widgets/Workspaces.qml`, `Wallpaper/*.qml`. Evidence: report 06 "Bugs", report 07 "Bugs and rule breaks".

- [ ] **Step 1:** As Task 6 step 1 for: staged files never clearing after a mixed deliver/fail round; `settleTimer` reassigning `ignoreIds` every 100 ms; the "saved" dwell running off screen; `DeviceTile.state` shadowing `Item.state` (rename to `phase`, with its readers); `Workspaces`' function named `focus` (rename to `focusSlot`); the wallpaper picker's `file://` accessible name.
- [ ] **Step 2:** STATIC `t7`, CHECKS. Commit.

### Task 8: Bugs in services and the shell

**Files:** Modify: `Services/NightLight.qml`, `Services/Brightness.qml`, `Commons/Bus.qml`, `Ui/IslandSurfaceBase.qml`, `Ui/Tint.qml`, `shell.qml`, `tools/qs-verify/run.sh`, and the showcase tooling that drives `authpreview`/`lockpreview` (find it with `grep -rn 'authpreview\|lockpreview' /home/ryan/nixos-cleanup --include='*.sh' --include='*.nix' --include='*.fish'`).

- [ ] **Step 1:** As Task 6 step 1 for: NightLight overwriting its saved state after a failed boot restore; Brightness keeping `_lastTarget` after a failed write; `Bus.snapTints` being one flag released by any surface's timer (count holders per surface key; tints un-snap when the count is zero).
- [ ] **Step 2:** Load `AuthPreview` and `LockPreview` only when `Quickshell.env("QS_PREVIEW") === "1"`; set `QS_PREVIEW=1` in the harness's `run.sh` and in the showcase tooling.
- [ ] **Step 3:** STATIC `t8`, CHECKS. Commit.
- [ ] **Step 4:** PHASE GATE 0. The hand-over to Ryan says: the pill orbits again; previews need `QS_PREVIEW=1`; which bugs were not reproduced.

---

## Phase 1: tokens

### Task 9: `Metrics` and `Timing`

**Files:** Create: `home/quickshell/Commons/Metrics.qml`, `Commons/Timing.qml`. Modify: `Commons/Theme.qml` and every reader. Create: `tools/qs-tokens/table.mjs` (the scratch scripts `tokens.mjs`/`scan.mjs` adapted to take the tree as an argument and print the table as TSV).

**Interfaces:**
- Produces `Metrics` (`pragma Singleton`, `Singleton` root, no I/O): every shared size, inset, gap, width, height and shadow token, **with the name and value it has in Theme today**.
- Produces `Timing`: every duration, delay, dwell, spring rate and damping token with today's name and value; `function ms(n)` (today's `Theme.duration` body); `readonly property int frame: 16`; `readonly property int debounce: 100`. It reads `Theme.reduceMotion`.
- `Theme` keeps: palette loading, colours and roles, fonts and weights, `reduceMotion`, `motionLog`, `lift()`, `withAlpha()`, `clamp01()`, `stableAccent()`, the `lift*` family.

- [ ] **Step 1:** `nix run nixpkgs#nodejs -- tools/qs-tokens/table.mjs home/quickshell > /tmp/tokens-now.tsv`; confirm the member count matches `grep -cE '^\s*(readonly )?property' Commons/Theme.qml`.
- [ ] **Step 2:** By script, move tokens by family (TSV column `family`) into the two new files and rewrite readers `Theme.x` to `Metrics.x` or `Timing.x`. Tokens whose only readers are relay files move too, under one `// Relay` heading in each file.
- [ ] **Step 3:** Replace `Theme.duration(` with `Timing.ms(`. Where the argument is a token that already reads `reduceMotion ? 1 : N`, drop the wrapper.
- [ ] **Step 4 (Review Focus 1):** Add harness check `theme-switch`: with the control centre open, write `rose-pine` to the scratch `~/.local/state/theme/name`, call `qs ipc call theme sync`, capture; the capture must equal a fresh `QS_THEME=rose-pine` run's `panel-control` state.
- [ ] **Step 5:** STATIC `t9` (identical), CHECKS. Commit.

### Task 10: Feature numbers leave the shared files

**Files:** Modify: `Commons/Theme.qml`, `Metrics.qml`, `Timing.qml`, and every feature file. Create where several files of one feature share numbers: `Lock/LockSpec.qml`, `Nearby/NearbySpec.qml`, `Bar/IslandSpec.qml`, `Phone/PhoneSpec.qml` (`pragma Singleton`, values only).

**Interfaces:** A token read from exactly one file becomes `readonly property <type> <sameName>` in a block at the top of that file's root, read unqualified or by the root id. A token read from several files of one directory moves to that directory's spec singleton under its present name without the feature prefix where the prefix is the singleton's name (`Theme.lockPillHeight` becomes `LockSpec.pillHeight`). A token read from two or more directories stays.

- [ ] **Step 1:** Regenerate the table. For each token with disposition `local`, move it by script; its comment block travels with it. Do it in four commits so each compares on its own: (a) `Bar/`, `Activities/`, `Notifications/`, `Osd/`, `Dictation/`, `Rebuild/`; (b) `Control/`, `Calendar/`, `Launcher/`, `Media/`, `Keys/`; (c) `Nearby/`, `Phone/`, `Recorder/`, `Power/`, `Session/`, `Theme/`, `Wallpaper/`, `Auth/`; (d) `Lock/`.
- [ ] **Step 2:** `Theme.islandCollapsedWidth()` and the six tokens only it reads move to `Bar/IslandSpec.qml` as `collapsedWidth(...)`; its three callers follow.
- [ ] **Step 3:** After each commit: STATIC (identical), CHECKS.
- [ ] **Step 4:** Print the member counts of the three shared files to `~/.cache/qs-audit/cleanup-notes.md`. Expected: about 300 or fewer in total at this point (the scales in Task 11 take it to about 170).

### Task 11: Scales, derived numbers, colour roles, pixel-identical

**Files:** Modify: `Commons/Metrics.qml`, `Timing.qml`, `Theme.qml`, `Ui/StrokeIcon.qml`, readers.

**Interfaces (all in `Metrics` unless noted):**
- `radiusSm: 8`, `radiusMd: 14`, `radiusPanel: barHeight`, `function pill(h) { return h / 2 }`.
- `fontCaption: 11`, `fontSmall: 12`, `fontBody: 13`, `fontEmphasis: 14`, `fontTitle: 17`, `fontDisplay: 22`.
- `glyph14`, `glyph16`, `glyph18`, `glyph20`, `glyph22`, `glyph24`, `glyph26`.
- `space2`, `space4`, `space6`, `space8`, `space10`, `space12`, `space14`, `space16`, `space20`, `space24`, `space28`, `space32`.
- `iconStroke: 1.75`; `accentWash: 0.12`, `accentWashStrong: 0.18`, `onAccentSoft: 0.72`, `ringTrack: 0.35`.
- `Theme`: one name per colour. `inkPrimary`, `inkSecondary`, `inkTertiary`, `canvas`, `accent`, `danger` replace readers of `text`, `subtle`, `muted`, `base`, `accentFill`, `urgent`, `dangerFill`; hue names stay.

- [ ] **Step 1:** Every token whose value already equals a step is replaced at its readers by the step, and deleted. Semantic names that several features read and that carry meaning stay as aliases of a step (`rowRadius: radiusMd`, `panelRadius: radiusPanel`); names that only repeat a surface's name (`calRadius`, `notifRadius`, `launcherWidth`) go.
- [ ] **Step 2:** Write the derived numbers of report 03 section 3 as expressions (pill radii as `Metrics.pill(height)`, `switchKnob`, the recorder card, the picker ladder, the shadow from `barHeight`). Each must evaluate to today's value; assert it in a throwaway `console.assert` run under the harness, then remove the asserts.
- [ ] **Step 3:** `StrokeIcon.strokeWidth` defaults to `Metrics.iconStroke`; delete the explicit `1.75`s only. Literal `Theme.withAlpha("white", a)` becomes `Theme.lift(a)`; literals equal to a named alpha take the name.
- [ ] **Step 4:** Name every bare Timer interval beside its Timer (`readonly property int <what>Ms`); UI frame timers of 16 take `Timing.frame`, debounces of 100 take `Timing.debounce`; the four `token + N` sites name the N.
- [ ] **Step 5:** Merge exact-duplicate durations only where the two names mean the same thing in one feature; otherwise leave both.
- [ ] **Step 6 (Review Focus 2):** `QS_VERIFY_WORK=/tmp/qsv-cleanup-motion tools/qs-verify/motion/record.sh home/quickshell /tmp/qsv-motion/t11 reduce` then `check.mjs /tmp/qsv-motion/t11/reduce --max-anim-ms 80`; expected: no failure that the baseline's reduce run does not have.
- [ ] **Step 7:** STATIC `t11` (identical), CHECKS. Commit.

### Task 12: Snaps

**Files:** Modify: `Commons/Metrics.qml`, feature locals. Create: `~/.cache/qs-audit/snaps/LIST.md` and before/after crops.

- [ ] **Step 1:** One commit per scale, in this order, each followed by STATIC against the previous commit's capture (not the baseline), so its diff is exactly that scale:
  - radius: `keycapRadius` 6 to 8, `pickerWallpaperPreviewRadius` 12 to 14;
  - type: 10 and 10.5 to 11, 11.5 to 12, 12.5 to 13, 15 to 14, 16 and 18 to 17;
  - glyph: 13 to 14, 15 to 16, 17 to 18, 21 to 20;
  - spacing: 3 to 2, 5 to 4, 7 to 8, 11 to 12, 13 to 12, 15 to 16, 17 to 16, 21 to 20, 23 to 24, 3.5 to 4;
  - stroke: 1.8 and 1.6 to 1.75;
  - alpha: accent washes 0.10 and 0.14 to 0.12, 0.16 to 0.18; `ConfirmGrid` disabled 0.5 to `Theme.disabledAlpha`.
- [ ] **Step 2:** For every differing state, measure the largest displacement and size change in the diff image. Over 2 px, or a control's proportions changed: drop the snaps in that state with the fewest readers until it passes, and keep the dropped value as a local. `switchInset`, `launcherRowGap` and `launcherInset` are not touched.
- [ ] **Step 3:** Write `LIST.md`: per snap the token, before, after, the states it shows in, and a before/after crop; then the list of snaps dropped and why.
- [ ] **Step 4 (Review Focus 3):** Run STATIC at `QS_SCALE=1.25` for the commit before Step 1 and the last commit (two runs, compared with each other); every differing state must be one already in `LIST.md`, and no text may differ outside the snapped items.
- [ ] **Step 5:** CHECKS. PHASE GATE 1; Ryan gets `LIST.md`; the last capture becomes the baseline.

---

## Phase 2: shared pieces

Each task: create the piece, move every call site in the same commit, STATIC (identical unless the task lists a drift), CHECKS, commit. Call sites are listed in the "Proposed abstractions" sections of reports 04 to 07.

### Task 13: `Label`

**Files:** Create: `Ui/Label.qml`. Modify: every file with a hand-styled `Text` (125 in 47 files).

**Interfaces:** `Label` is a `Text` with `font.family: Theme.uiFont`, `color: Theme.inkPrimary`, and
`property int size: Label.Body` (enum `Caption`, `Small`, `Body`, `Emphasis`, `Title`, `Display` mapping to `Metrics.font*`), `property int weight: Label.Regular` (enum `Regular`, `Medium`, `Semibold`, `Bold` mapping to Theme's weights), `property bool tabular: false`, `property bool mono: false`. A site with an off-scale size sets `font.pixelSize` itself.

- [ ] **Step 1:** Create it; move the sites. Icon-font `Text` (inside `StrokeIcon`), the lock numerals, emoji and `MorphPart`'s ghost text stay `Text`.
- [ ] **Step 2 (Review Focus 3):** STATIC `t13` identical at scale 1 and at `QS_SCALE=1.25` (against a 1.25 run of the previous commit). CHECKS. Commit.

### Task 14: `Plate`, `FocusRing`, `IconLabel`

**Files:** Create: `Ui/Plate.qml`, `Ui/FocusRing.qml`, `Ui/IconLabel.qml`. Modify: `ButtonBase`, `Button`, `ListRow`, the tiles, `SegmentCell`, `Switch`, `Segmented`, `TextField`, `SectionLabel`, `MediaScrub`, `Calendar/CalendarPanel.qml`, and the nine static-lift sites in report 04.

**Interfaces:**
- `Plate { property real rest; property real hover: rest; property bool hovered; property bool lit; property color litColor; property bool edge; radius }`: a `Rectangle` whose colour is `Theme.lift(hovered ? hover : rest)` or `litColor`, through a `Tint`.
- `FocusRing { property bool shown; radius }`: the 1 px ring with the `focusFade`, `morphIgnore` set.
- `IconLabel { property string icon; property string text; property color ink; property real iconSize; property real gap; property int size; property int weight }`: one `Tint`ed ink for both.

- [ ] **Step 1:** Create and move. `IconLabel` tints an ink that today cuts while its ground tints (`Button` pill icon, `SegmentCell`): that is the one allowed drift; it shows only in motion, so STATIC stays identical.
- [ ] **Step 2:** STATIC `t14`, CHECKS. Commit.

### Task 15: `Card`, `Chip`, `EmptyNote`, `EmptyState`, `TwoLineRow`, `ScrollFade`, `TransportButton`

**Files:** Create each in `Ui/`. Modify the sites named in reports 05 (items 5, 13, 14), 06 (items 5, 6, 9) and 07 (A5).

**Interfaces:** `Card { radius: Metrics.radiusMd; property real lift }` (hairline `liftEdge`); `Chip { icon; text; ink; fill; outlined }`; `EmptyNote { text; shown }` (no animation: its sites cut today); `EmptyState { icon; title; actionText; signal activated() }`; `TwoLineRow { icon; iconColor; title; subtitle; default property alias trailing }`; `ScrollFade { flickable }`; `TransportButton { kind: "previous" | "toggle" | "next" }` carrying the `media.*` morph keys the two sites declare today.

- [ ] **Step 1:** Create and move. Drop any of these that ends with one caller or needs a flag per site; note it in `cleanup-notes.md`.
- [ ] **Step 2:** STATIC `t15`, CHECKS. Commit.

### Task 16: `Ring` as the one arc, `MinuteClock`, `Icons`

**Files:** Modify: `Ui/Ring.qml`, `Bar/Widgets/Gauge.qml`, `Ui/Spinner.qml`. Delete: `Bar/Widgets/GaugeArc.qml`, `Commons/IconPaths.qml`. Create: `Services/MinuteClock.qml`. Modify: `Ui/IslandClock.qml`, `Bar/Island.qml`, `Notifications/Notifications.qml`, `Lock/LockView.qml`, `Phone/PhonePanel.qml`, `Commons/Icons.qml` and the 40 `IconPaths` call sites.

**Interfaces:** `Ring { size; stroke; startAngle: -90; sweep: 360; value; trackColor; fillColor }`. `MinuteClock` singleton: `readonly property date date`, re-armed on `Bus.clockRefreshed`. `Icons` holds the names and the SVG marks; `Icons.wifiGlyph(strength, connected)` unchanged.

- [ ] **Step 1:** Create and move.
- [ ] **Step 2 (Review Focus 5):** In `displays-two`, both outputs' pills show the same minute after `qs ipc call` of the clock refresh; capture both outputs and compare the pill crops.
- [ ] **Step 3:** STATIC `t16`, CHECKS. Commit.

### Task 17: `KeyedModel` and list transitions

**Files:** Create: `Ui/KeyedModel.qml`, `Ui/ListEnter.qml`, `Ui/ListExit.qml`, `Ui/ListDisplace.qml`, `tools/qs-verify/js/keyed.test.mjs`, `Ui/Keyed.js` (the pure diff). Move: `Control/KeyedList.qml` to `Ui/KeyedList.qml`. Modify: `Launcher/Launcher.qml`, `Nearby/NearbyPanel.qml`, `Control/WifiView.qml`, `BluetoothView.qml`, `AudioView.qml`.

**Interfaces:** `Keyed.js` `diff(oldKeys: string[], rows: object[], keyField = "key") -> { removes: int[], inserts: {index, row}[], moves: {from, to}[], updates: {index, row}[] }`. `KeyedModel` is a `ListModel` with `function sync(rows, keyField)` applying it. `ListEnter`/`ListExit`/`ListDisplace` are `Transition`s with `property bool enabled: true` and today's `KeyedList` values (`listEnter`, `listExit`, `listSettle`, `listRise`, `listExitScale`).

- [ ] **Step 1:** Write `keyed.test.mjs`: empty to rows inserts in order; same keys with changed fields gives updates only; a removed middle key gives one remove; a reorder gives moves and no remove; duplicate keys keep the first. Run JS; expected: FAIL (no module).
- [ ] **Step 2:** Implement `Keyed.js`; JS passes. Build `KeyedModel` on it; move the three diffs and the three transition sets. The launcher and Nearby take `KeyedList`'s timings: list each value that changed in `cleanup-notes.md` as a drift.
- [ ] **Step 3:** STATIC `t17`; MOTION for the scenarios with lists (`subview`, `controls`) against baseline. CHECKS. Commit.

### Task 18: The tiles and `LoginPill`

**Files:** Create: `Ui/TileBase.qml`, `Ui/ControlTile.qml`, `Ui/ChoiceTile.qml`, `Ui/CarouselTile.qml`, `Ui/DiscTile.qml`. Delete: `Ui/Tile.qml`. Modify: every `Tile { kind: ... }` caller, `Ui/LoginPill.qml`, `Auth/AuthPrompt.qml`.

**Interfaces:** Each new tile keeps the properties its `kind` used on `Tile` (`active`, `current`, `stacked`, `confirms`, ...) and the `morphRole` it declared (`tile`, `choice`, `carousel`, `device`). `DiscTile` is the old `Device` kind; `Nearby/DeviceTile.qml` keeps its name and uses it.

- [ ] **Step 1:** Split; move callers. `LoginPill`: delete `framed`, `ui`, `curveIcons`, `shakeX`, `keyPressed`, `keyReleased` if still unread; build dot slots with a `Repeater` whose model is the count shown, not 64.
- [ ] **Step 2:** STATIC `t18` (the auth states cover `LoginPill`), CHECKS. Commit.

### Task 19: The pill skeleton and moments

**Files:** Create: `Ui/PillStage.qml`, `Ui/Dwell.qml`, `Activities/EdgeTrigger.qml`. Modify: `Ui/TransientSurface.qml` (allowed: `want`, the size default, `swap`), `Activities/Moments.qml`, `MomentSource.qml`, `PluggedSource.qml`, `WifiSource.qml`, `ActivitySources.qml`, `Rebuild/RebuildPill.qml`, `Recorder/RecordingFailedPill.qml`, `Osd/Osd.qml`, `Dictation/DictationPill.qml`, `Nearby/SharingPill.qml`, `Notifications/Notifications.qml`, `shell.qml`, `tools/qs-verify/shoot.sh` (the `activities` ipc calls).

**Interfaces:**
- `TransientSurface`: `property bool want: false`; `property bool blockedByPanel: Bus.islandOpenFor(screenName)`; `wanted: want && focused && !blockedByPanel`; `openWidth/openHeight/openRadius` default to the pill row; `function swap(change) -> bool` (true when the old contents were carried by `swapBegin`).
- `PillStage { required property var host }`: centred and snapped in the content box at the pill row's size.
- `Dwell { property int duration; property bool running; property bool paused; signal elapsed(); function restart() }`: one single-shot `Timer` armed for the remainder; no periodic wake-ups.
- `EdgeTrigger { property bool value; property bool present: true; property int warmup; property int hold; signal risen() }`.
- `MomentSource`: `property bool when`, `property var spec`; `spec.compact: true` takes the default sizes. ipc `activities fake <kind> <value>` finds the source by `kind`.

- [ ] **Step 1:** Create and move the seven pills. Remove inline `component`s in `SharingPill` and `PillMarks` (each becomes a file).
- [ ] **Step 2:** STATIC `t19`; MOTION against baseline (every transient scenario). CHECKS. Commit.
- [ ] **Step 3:** PHASE GATE 2. Hand-over lists the list-timing drifts from Task 17.

---

## Phase 3: feature files

Each task splits files along the seams the reports name and moves no pixel. Each: STATIC identical, CHECKS, commit. A file in the "Create" list holds what the report describes for it; new files open with a one-line purpose.

### Task 20: Control centre sub-views and home

**Files:** Create: `Control/ActionRow.qml`, `RescanButton.qml`, `NodePicker.qml`, `StreamRow.qml`, `PasswordReveal.qml`, `TileRow.qml`, `NotificationList.qml`, `NotificationSlot.qml`. Modify: `WifiView`, `BluetoothView`, `AudioView`, `HomeView`, `ControlCenter`, `MediaCard`, `Media/MediaPanel.qml`, `Services/Volume.qml`.

**Interfaces:** `ActionRow { glyph; label; sublabel; selected; property var action: ({ text, kind, run }); property var secondary }` (a row click runs `action.run`). `Volume.sinkName`, `Volume.nodeLabel(node)`. The control centre's keys go through `Panel.take`; `h j k l` then move through the tiles, as in every other panel.

- [ ] **Step 1:** Split and move (report 05, abstractions 3, 4, 6, 7, 9, 11, 12). Wi-Fi keeps its two lists; turning it into one flat list is project 2.
- [ ] **Step 2:** STATIC `t20`. The populated lists are not covered: add to the gate's hand-over "connect, forget and rescan on real Wi-Fi and Bluetooth". CHECKS. Commit.

### Task 21: Displays

**Files:** Create: `Control/DisplayTile.qml`, `DisplayCanvas.qml`, `AlignPad.qml`, `DisplayLayout.js`, `tools/qs-verify/js/displays.test.mjs`. Modify: `Control/DisplaysView.qml`.

**Interfaces:** `DisplayLayout.js` holds the pure geometry now inline in the view (fit monitors into the canvas, snap a dragged tile to its neighbours' edges, alignment). Signatures follow the functions as they exist; no behaviour change.

- [ ] **Step 1:** Write `displays.test.mjs` for each moved function from values read off the current code: two side-by-side 1920x1080 outputs fit the canvas at the present scale; a tile dropped within the snap distance of an edge lands on it; one dropped beyond does not. JS fails, move the functions, JS passes.
- [ ] **Step 2:** Split the view. STATIC `t21` (`displays-two` covers it), CHECKS. Commit.

### Task 22: Calendar

**Files:** Create: `Calendar/CalendarGrid.qml`, `DayCell.qml`, `AgendaRow.qml`, `DayAgenda.qml`. Modify: `Calendar/CalendarPanel.qml`, `Services/Calendar.qml` (`dayMap`, `dayNumber`, `relativeLabel`, `todayKey`).

- [ ] **Step 1:** Split. Feed the harness's `cal-events.tsv` fixture so the agenda rows are captured (add a `calendar-agenda` state to `shoot.sh`, baseline it on the previous commit first).
- [ ] **Step 2:** STATIC `t22`, CHECKS. Commit.

### Task 23: Launcher

**Files:** Create: `Launcher/ScopeChip.qml`, `Launcher/ResultItem.qml`. Modify: `Launcher/Launcher.qml`, `LauncherRow.qml`, `AnswerRow.qml`, `Ui/RowList.qml`, `Nearby/FilePicker.qml`.

**Interfaces:** `RowList.reveal(index)`: scroll so the row is in view on the spring both sites hand-roll today, with the same rate.

- [ ] **Step 1:** Split and move. STATIC `t23` (`launcher-*` and `picker-*` states), MOTION `controls`. CHECKS. Commit.

### Task 24: Nearby

**Files:** Create: `Nearby/SendSession.qml`, `SendView.qml`, `ReceiveView.qml`, `ConsentCards.qml`, `PickerHeader.qml`, `PickerPreview.qml`, `FileThumb.qml`, `OfferRow.qml`, `Commons/Files.js`, `tools/qs-verify/js/files.test.mjs`. Modify: `Nearby/NearbyPanel.qml`, `FilePicker.qml`, `HoverPreview.qml`, `StagedFileRow.qml`, `IncomingCard.qml`, `SharingPill.qml`, `Services/Nearby.qml`, and the `baseName`/`sizeLabel` copies in `Services/Wallpapers.qml`, `Phone.qml`, `Polkit.qml`, `Account.qml`, `Recorder.qml`.

**Interfaces:** `Files.js`: `baseName(path)`, `extOf(path)`, `fileKind(path) -> "image"|"video"|"audio"|"text"|"archive"|"folder"|"file"`, `isPreviewableImage(path)`, `imageExts`, `sizeLabel(bytes)`, `pathFromUrl(url)`. Values and strings as `Services/Nearby.qml` returns them today.

- [ ] **Step 1:** `files.test.mjs` from today's behaviour: `baseName("/a/b.tar.gz") === "b.tar.gz"`, `extOf` lower-cases, `sizeLabel` at 0, 1023, 1024 and 1.5e9 bytes equals what `Nearby.sizeLabel` prints now, `pathFromUrl("file:///a%20b")`. JS fails, move, JS passes.
- [ ] **Step 2:** Split the panel and the picker. STATIC `t24`, CHECKS. Commit.

### Task 25: Phone and the four small panels

**Files:** Create: `Phone/PhoneScreen.qml`, `PhoneTiles.qml`, `PhoneImagePicker.qml`. Modify: `Phone/PhonePanel.qml`, `Power/*.qml`, `Session/*.qml`, `Theme/*.qml`, `Wallpaper/*.qml`, `Ui/ConfirmGrid.qml`, `Ui/CarouselPanel.qml`.

- [ ] **Step 1:** Split. The tile grid's model becomes stable (tiles bind to the service's values; the model array is not rebuilt on battery or ringing changes). The wrapper Power and Session repeat moves into `ConfirmGrid`; Theme's and Wallpaper's into `CarouselPanel`.
- [ ] **Step 2:** STATIC `t25`, CHECKS. Commit.

### Task 26: Lock

**Files:** Create: `Lock/LockGround.qml`, `LockPill.qml`, `ClockMetrics.qml`, `ClockRoll.qml`, `GlassDigits.qml`, `ClockPlate.qml`, `LockCapture.qml`, `LockAuth.qml`. Modify: `Lock/LockView.qml`, `Lock.qml`, `LockPreview.qml`, `LockReveal.qml`.

**Interfaces:** `LockView { required property LockReveal reveal; signal presented() }` replaces the thirteen pass-through properties.

- [ ] **Step 1:** Move the clock plate subtree whole: no change to any `layer.*`, `textureSize`, `samples`, `format`, `ShaderEffect` property or uniform. `Shaders/lockglass.frag` is not edited.
- [ ] **Step 2:** STATIC `t26`: the three `lock-preview*` states must be byte-identical to the previous commit's, with no allowance. Also play `lockpreview time 09:41` then `time 09:42` and compare the settled frame. MOTION lock scenarios (own run). CHECKS. Commit.

### Task 27: The bar's island

**Files:** Create: `Bar/IslandCard.qml`, `Bar/IslandHover.qml` (the hover, pin, return and awaiting-pointer state as a non-visual object), `Bar/DropWell.qml`. Modify: `Bar/Island.qml`, `Bar/PhoneSatellite.qml`, `Bar/Widgets/Equaliser.qml`, `Bar/Widgets/Workspaces.qml`.

- [ ] **Step 1:** Split `Island.qml`. The properties `IslandOrigin`, `IslandSurfaceBase` and `Bus` read off the island (`handContents`, `returnContents`, `returned`, `awaitingPointer`, `suppressed`, `claimed`) keep their names on the root.
- [ ] **Step 2:** STATIC `t27` (island, card and `card-returned` states); MOTION all. CHECKS. Commit.
- [ ] **Step 3:** Replace hand-placed x/y layouts with `Row`/`Column` across the phase's files only where STATIC stays identical; otherwise leave the numbers as locals. Every remaining inline `component` in the tree becomes a file (`grep -rn '^\s*component ' home/quickshell` must print nothing). STATIC, CHECKS. Commit.
- [ ] **Step 4:** PHASE GATE 3.

---

## Phase 4: services

### Task 28: `Query` and `PathQuery`

**Files:** Create: `Services/Query.qml`, `Services/PathQuery.qml`. Modify the sites in report 08's inventory table marked `Query`/`PathQuery`.

**Interfaces:**
```
Query (extends QueuedProcess): property string output; property string errText;
  property int timeoutMs: 0; property bool logFailures: true;
  function run(); function exec(args);
  signal answered(string text)   // never for a stale or killed run
  signal failed(int code, string message)
PathQuery: property string path; property var build  // function(path) -> string[]
  same signals; a new path while one runs drops the old answer
```

- [ ] **Step 1 (Review Focus 4):** Add harness checks before moving anything, run against the new types through a scratch QML file loaded by `quickshell -p`: a command that does not exist emits `failed` once and logs once; a command that exits 3 emits `failed(3, stderr's last line)`; `timeoutMs: 200` on `sleep 5` emits `failed` within 400 ms and a following `run()` works; two `PathQuery` paths set 10 ms apart deliver only the second answer. Expected first: FAIL (types missing).
- [ ] **Step 2:** Implement; the checks pass. Move the sites one service at a time.
- [ ] **Step 3:** STATIC `t28`, CHECKS. Commit.

### Task 29: `Command` modes, `WatchedFile`, `PolledFile.active`

**Files:** Modify: `Services/Command.qml`, `PolledFile.qml`, `SysfsGauge.qml`, `Nearby.qml`, `Brightness.qml`, `Volume.qml`, `Phone.qml`, `KeyboardBacklight.qml`, `Keymap.qml`, `EmojiSearch.qml`, `Account.qml`. Create: `Services/WatchedFile.qml`.

**Interfaces:** `Command { property bool queue: false; property bool coalesce: false; property int minIntervalMs: 0; function exec(args, undo, label) }`. `WatchedFile { path; property int retryMs: 2000; text(); signal changed() }` (re-tries while the file is absent). `PolledFile { property bool active: true }`. `SysfsGauge { property int pollMs: 0 }`.

- [ ] **Step 1 (Review Focus 4):** Scratch checks as in Task 28: `queue` runs three `exec`s in order; `coalesce` with `minIntervalMs: 20` given ten `exec`s in 5 ms runs the first and the last only; `WatchedFile` on a path created 1 s after start emits `changed` once it exists. FAIL first, then implement.
- [ ] **Step 2:** Move Nearby's eight calls (and delete its inline `component Call`), the Brightness and Volume throttles (Volume sets an absolute target like Brightness), and Phone's commands. STATIC `t29` (the OSD and Nearby states cover them), CHECKS. Commit.

### Task 30: Start-up and polling

**Files:** Modify: `Services/Omnibox.qml`, `Provider.qml`, `AppSearch.qml`, `Calculator.qml`, `ClipboardHistory.qml`, `EmojiSearch.qml`, `Launcher/Launcher.qml`, `Services/SystemStats.qml`, `ChargeMode.qml`, `Privacy.qml`, `Recorder.qml`, `PowerProfiles.qml`, `Bar/PhoneSatellite.qml`, `Bar/Widgets/Equaliser.qml`, `Bar/Island.qml`.

**Interfaces:** `Provider { property bool active }`: a provider does its first-use work (file parses, probes) when `active` first turns true, which is when a query reaches it or its scope opens. `SystemStats { property int watchers }`: polls only while `watchers > 0` and reads at once when it goes from 0 to 1.

- [ ] **Step 1:** Add a harness check `cold-start`: count processes the shell spawns in its first 3 s (`strace -f -e trace=execve` on the harness's quickshell, or the stub PATH's call log). Record the number on the previous commit.
- [ ] **Step 2:** `Launcher`'s `openHeight` stops instantiating `Omnibox` at start; providers go lazy; `cliphist list` runs only with the clipboard scope open. System stats gated on the hover card; `ChargeMode`'s 5 s poll removed; the camera scan runs only when a `/dev/video*` exists; `Recorder` uses `onProcessIdChanged` and `lastIpcObject.refreshRate`; `PowerProfiles` on Quickshell's UPower `PowerProfiles`; the satellite's geometry rebuild skipped with no phone; the equaliser paused while `Bus.covers` its output or the session is locked.
- [ ] **Step 3:** `cold-start` again; expected: fewer spawns, and none of `readlink`, the qalc config write, the rates check or `cliphist` among them. STATIC `t30`, CHECKS. Commit.

### Task 31: Helpers and service splits

**Files:** Create: `Commons/Json.js`, `Commons/Colour.js`, `Commons/Zones.js`, tests in `tools/qs-verify/js/`. Modify: `Services/Calculator.qml`, the 11 `JSON.parse` try/catch sites. Split `Services/Nearby.qml`, `Phone.qml`, `Rebuild.qml`, `Polkit.qml` along their `// ----` divider comments into a singleton plus helpers in the same directory; the singleton's public members do not change.

**Interfaces:** `Json.tryParse(text, fallback)`. `Colour.js` and `Zones.js` export the functions `Calculator` holds today for colour conversion and time zones, under their present names.

- [ ] **Step 1:** Tests first from today's outputs (the `launcher-calc` state's answers; three colour conversions and three zone questions run through the current `Calculator` and pinned). JS fails, move, JS passes.
- [ ] **Step 2:** STATIC `t31`, CHECKS. Commit.

### Task 32: `Bus`, `shell.qml`, shader includes

**Files:** Create: `Commons/LockState.qml`, `Shaders/shadow.glsl`. Modify: `Commons/Bus.qml`, readers of its lock members, `shell.qml`, `tools/qs-shaders.sh`, `Shaders/shadow.frag`, `lockpatch.frag`, `satellite.frag`.

- [ ] **Step 1:** Move `Bus`'s lock members to `LockState` with the same names. The ipc handlers in `shell.qml` that only toggle or close join the generated loop; `theme` and `nearby` stay hand-written.
- [ ] **Step 2:** `tools/qs-shaders.sh` expands `// #include "file.glsl"` before compiling, in both modes (`--check` too); the three shaders include `shadow.glsl`. The generated `.qsb` files must be byte-identical to the previous commit's (`git diff --stat -- '*.qsb'` prints nothing).
- [ ] **Step 3:** STATIC `t32`, `shader-smoke.sh`, CHECKS. Commit. PHASE GATE 4; hand-over lists Night Light, power profiles and the camera mark for Ryan to try.

---

## Phase 5: comments, docs, boards

### Task 33: Comments

**Files:** Every `.qml`, `.js` and `.frag` outside the relay list. Create: `Lock/README.md`, `Nearby/README.md`, `Services/README.md`.

- [ ] **Step 1:** In four commits by directory group (as Task 10), apply the rule: delete comments that restate the code or tell history (dates, names, "used to", "was"); move explanations longer than about six lines into the feature's README or `Ui/README.md`, leaving one line that points there; keep every comment that gives a reason or warns of a trap, and the one-line purpose at the top of each file. A `.frag` change is comment-only: its `.qsb` must not change.
- [ ] **Step 2:** After each commit: `git diff --stat` shows only comment and blank lines changed (`git diff -w -G'^\s*[^/ ]' --stat` prints nothing for code), STATIC identical, CHECKS.
- [ ] **Step 3:** Print comment lines before and after per directory to `cleanup-notes.md`.

### Task 34: README

**Files:** Modify: `home/quickshell/Ui/README.md`, `tools/qs-verify/README.md`.

- [ ] **Step 1:** Rewrite the sections the clean-up changed: the new pieces (Label, Plate, FocusRing, IconLabel, Card, Chip, EmptyNote, EmptyState, TwoLineRow, KeyedModel and the list transitions, the four tiles, PillStage, Dwell, `want`, `swap`, EdgeTrigger, MinuteClock, Query, PathQuery, WatchedFile, Command's modes), "to add a pill" and "to add a moment" with the shorter recipes, and the rules: shared scales live in `Metrics`, motion numbers in `Timing`, a number one file reads lives in that file. The surface and morph sections stay as they are.
- [ ] **Step 2:** CHECKS. Commit.

### Task 35: Boards

**Files:** `~/Designs/NixOSQuickshell.fig` through the OpenPencil tools. One agent only.

- [ ] **Step 1:** From `~/.cache/qs-audit/snaps/LIST.md`, apply each landed snap to the matching components on all three theme pages (radii, type sizes, glyph sizes, spacing, stroke).
- [ ] **Step 2:** Export the changed boards and compare each by eye with the harness capture of the same state; save the file.

### Task 36: Close

- [ ] **Step 1:** Whole-branch review by a fresh reviewer against the spec: every Goal met, every Non-goal and Anti-goal respected, the relay files' diff limited to the four allowed kinds (`git diff main~N -- <relay files>` read in full).
- [ ] **Step 2:** STATIC, MOTION, CHECKS on the final tree. PHASE GATE 5.
- [ ] **Step 3:** Report to Ryan: member counts of `Theme`/`Metrics`/`Timing`, lines before and after, snaps landed and dropped, bugs fixed and not reproduced, what he should try by hand. Remove the worktree and branch once merged.
