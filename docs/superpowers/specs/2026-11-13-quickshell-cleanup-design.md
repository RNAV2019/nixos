# Quickshell clean-up (project 1 of 3)

Date: 2026-11-13. Scope: `home/quickshell` and `tools/qs-verify`.

## Why

Ryan asked for the whole shell to be optimised, made reusable and cleaned up, with consistent
numbers, fewer comments and no dead code, and for it to feel more alive. Eight read-only audits
(reports in `~/.cache/qs-audit/01..08-*.md`, per-token table `tokens.tsv`, literals
`03-literals.tsv`) found three separate jobs. He chose the order:

1. **Clean-up** (this document).
2. **Life inside panels**: controls, icons, numbers, lists. Its own design, after this.
3. **Handover**: panels and pills move into one stage window per screen. Its own design, after
   the spikes in `~/.cache/qs-audit/spikes/`.

Clean-up goes first so that the motion work lands once, in shared pieces, instead of in three
drifted copies.

## Goals

- `Commons/Theme.qml` holds shared things only. From 945 members to about 170, split into
  `Theme`, `Metrics` and `Timing`.
- Radii, type sizes, glyph sizes, spacing and alphas sit on named scales. Every value that moved
  is listed for Ryan.
- Every layout, recipe and process pattern that is written more than once has one home.
- No dead code, no inline `component`, no file doing several jobs where the seams are clear.
- Comments say why, or warn of a trap. Nothing restates code or tells history.
- The bugs the audits found are fixed, each verified first.
- Nothing that polls or animates while nothing shows it.

## Non-goals

- **No change of feel.** Spring rates, durations, curves and choreography stay as they are.
  Anything that would change how something moves belongs to project 2, including the glyph-swap
  primitive, hover timing, the faster control spring and rolling digits.
- **No handover work.** The relay files are left alone apart from dead code (list under
  "Relay files").
- No new features and no restyling beyond the listed snaps.
- No row-height or art-size scale: those numbers are each one component's measurement.

## Anti-goals

- A snap Ryan was not shown.
- An abstraction with one caller.
- A shared piece that needs more flags than the copies it replaced had lines.
- Losing a comment that records a trap.
- A change whose check is not stated: either the harness shows it, or the hand-over names it
  as checked by reading and by Ryan's use.

## Constraints

- The live shell runs from the main checkout and hot-reloads on every write. All work happens in
  a worktree (`~/nixos-cleanup`, branch `refactor/cleanup`); main is only fast-forwarded.
- New files break hot reload, so each merge needs Ryan to restart the shell outside T3 Code.
- `tools/qs-verify` is the check: screenshots against a baseline made in the same conditions,
  `QS_THEME=ariadne`, own `QS_VERIFY_WORK`; `motion/check.mjs` for motion regressions.
  `nix build .#checks.x86_64-linux.quickshell-qmlformat` and `quickshell-shaders` must pass.
- One agent at a time drives OpenPencil (`~/Designs/NixOSQuickshell.fig`).
- The lock screen's liquid-glass clock must look exactly as it does now: texture sizes, sample
  counts, formats and `lockglass.frag` are not touched.
- No python3 on PATH; scripted edits use bash or `nix run nixpkgs#nodejs`.

## Approaches

How to carry the clean-up out. Ryan left this to me; the choice is mine.

1. **By layer, in phases, each gated by the harness (chosen).** Fixes, then tokens, then shared
   pieces, then feature files, then services, then comments and docs. Each phase is one kind of
   change, so a pixel-identical phase can be proven pixel-identical, and a snap phase shows only
   its snaps. Costs: several passes over some files.
2. **By directory.** Each feature cleaned completely in one pass. Fewer visits per file, but
   every diff mixes token moves, new primitives, splits and snaps, so nothing can be proven
   identical, and shared pieces get designed from the first feature that needs them.
3. **One scripted rewrite.** Fastest, and unreviewable.

Chosen: 1. The harness is only useful when a diff has one cause.

What Ryan decided in conversation (2026-11-13):

- Snaps to a shared scale are fine when they are within a pixel or two and listed; the `.fig`
  boards are updated to match.
- A number that only one file reads lives in that file, not in Theme.
- Comments: keep the why and the traps; cut restating and history; long explanations move to a
  README; a one-line purpose at the top of each file stays.

## Design

### Phase 0: baseline and fixes

Pixel-identical unless marked.

- Record the harness baseline on main, twice, to learn the noise.
- Widen the harness before the phases that need it (my call): a lock state through
  `lockpreview` at a frozen clock on a fixed wallpaper, the file picker, Nearby's send view
  with staged files, the launcher's clipboard and emoji scopes, and a second headless output
  for Displays. Populated Wi-Fi and Bluetooth lists, Night Light and power profiles need
  system-bus mocks the harness leaves out on purpose; those are checked by reading and by
  Ryan's use, and each hand-over says so.
- **Revive `OledCare`.** Commit 69e32f2 meant to keep the burn-in orbit but removed the last
  reference to the singleton, so it has not run since. Instantiate it from `shell.qml`, and add
  a harness state that proves the pill shifts. (Visible: the pill orbits by ±2 px again.)
- Dead code: the unused `Bus` members (`islandHeld`, `islandHeldFor`, `islandTaken`,
  `transientKeys`, `pillSlideX` if still unwritten once `OledCare` runs),
  `FrostedSurface.screenOffsetX/Y`, `Island.settled`, `CollapsedPill.clockShift`, the seven dead
  Theme tokens, about 45 unused properties and variants on the primitives (list in report 04),
  `morphSlot` declarations nobody sets, ten unused icon names, `lastDir`, `Control/Util.qml`,
  the launcher providers' write-only `matches` machinery, unused imports and ids,
  `Button.Danger`, the `activities charger` ipc.
- Shader early-outs: `shadow.frag` returns before its blur on interior pixels;
  `roundedclip.frag` returns when coverage is zero.
- Bugs, each reproduced in the harness or by reading before it is fixed. If one does not
  reproduce, it is reported and left.
  - Both Rescan buttons do nothing while the view is open.
  - Wi-Fi `pendingSsid` strands a state, so Back needs two presses.
  - Calendar "today" goes stale past midnight; `CalendarPanel` scans events once per cell.
  - Nearby: staged files never clear after a mixed deliver/fail round; `settleTimer` reassigns
    `ignoreIds` every 100 ms; the "saved" dwell runs while the pill is off screen.
  - `MediaScrub.nudge` can seek to NaN on a zero-length track.
  - `Bus.snapTints` is one global flag released by every surface's own timer.
  - NightLight can overwrite its saved state after a failed boot restore.
  - Brightness keeps a stale `_lastTarget` after a failed write.
  - `PhonePanel`'s clock lacks the refresh nudge (fixed by `MinuteClock` in phase 2).
  - `DeviceTile.state` shadows `Item.state`; `Workspaces` has a function named `focus`.
  - `AuthPreview` and `LockPreview` are instantiated in the live shell: load them only when
    `QS_PREVIEW=1`, and set that in the harness and the showcase tooling.

### Phase 1: tokens

Source of truth for every move: `~/.cache/qs-audit/tokens.tsv`, re-derived by script at the
start of the phase since the tree will have moved.

- **Three singletons** in `Commons/`:
  - `Theme`: palette loading, colours, fonts and weights, `reduceMotion`, `lift()`,
    `withAlpha()`.
  - `Metrics`: the scales below and the geometry several features share (`barHeight`,
    panel widths and insets, the pill row set, shadow room).
  - `Timing`: durations, dwells, spring rates and dampings, with their present values, and
    `ms(n)` as the only place reduce-motion shortens a raw duration. The 32 call sites that
    wrap an already reduce-aware token in `Theme.duration()` lose the wrapper.
- **Feature numbers** move out of Theme into a `readonly property` block at the top of the one
  file that reads them. Where several files of one feature share a set (lock, Nearby, island,
  phone), they go in one spec singleton beside the feature (`Lock/LockSpec.qml`). Their
  comments travel with them.
- **Scales** (in `Metrics`):
  - Radius: `radiusSm` 8, `radiusMd` 14, `radiusPanel` = `barHeight` (36), `pill(h)` = h / 2,
    and inner = outer minus inset written as that. The dozen `xRadius: panelRadius` aliases go.
  - Type: 11, 12, 13, 14, 17, 22.
  - Glyph: even sizes 14 to 26.
  - Spacing: a 2 px grid to 16, then 20, 24, 28, 32.
  - Alpha: the `lift*` family keeps every value it has. Repeated `withAlpha` literals get
    names at their present values (0.72 on accent ink, 0.35 ring track). The seven accent
    washes become two: `accentWash` 0.12 and `accentWashStrong` 0.18. The ten-step alpha scale
    in `tokens.tsv` is not taken.
  - `iconStroke` 1.75, as `StrokeIcon`'s default; the 35 hand-written 1.75 / 1.8 / 1.6 go.
- **Derived numbers are written as derived**: the forty relationships in report 03 section 3
  (`switchKnob = switchHeight - 2 * switchInset`, the recorder card from the power menu's
  tiles, the file picker's x ladder, the shadow from `barHeight`).
- **Colour names:** one name per colour outside Theme. Roles (`inkPrimary`, `inkSecondary`,
  `inkTertiary`, `canvas`, `accent`, `danger`) replace `text`, `subtle`, `muted`, `base`,
  `accentFill`, `urgent`; the hue names (`love`, `gold`, `foam`, ...) stay for uses that mean
  the hue.
- **Timer intervals** get a name beside their Timer; the UI frame and debounce timers share
  `Timing.frame` and `Timing.debounce`.
- **Durations:** only exact duplicates merge. No duration changes value in this project.

**Snaps taken** (my calls under Ryan's "within a pixel or two, listed" rule; the full list with
before and after goes to him with the phase's screenshots):

- Radius: `keycapRadius` 6 to 8, `pickerWallpaperPreviewRadius` 12 to 14.
- Type: 10 and 10.5 to 11, 11.5 to 12, 12.5 to 13, 15 to 14, 16 and 18 to 17.
- Glyph: 13 to 14, 15 to 16, 17 to 18, 21 to 20.
- Spacing: odd values to the even neighbour (3 to 2, 5 to 4, 7 to 8, 11 to 12, 13 to 12,
  15 to 16, 17 to 16, 21 to 20, 23 to 24, 3.5 to 4).
- Stroke: 1.8 and 1.6 to 1.75.
- Alpha: accent washes of 0.10 and 0.14 to 0.12, 0.16 to 0.18. `ConfirmGrid`'s disabled 0.5 to
  the shared 0.4.

**A snap is judged on screen, not per token.** It lands only if nothing drawn moves or changes
size by more than 2 px once derivations and stacked gaps are followed through, and no control's
own proportions change. Where snaps compound past that, the ones with the fewest readers are
dropped until the total is inside it. Known cases: `switchInset` stays 3 (the knob would grow
from 20 to 22), `launcherRowGap` stays 3 (an eight-row list would lose 7 px), and the control
centre's stacked gaps take at most 2 px between them.

**Not snapped; kept as a local number unless Ryan opts in:** the media titles at 19, the
launcher answer at 24, glyphs at 12 and 22, `dictationRadius` 24, and every spacing move of
2 px. `launcherInset` stays 14.

### Phase 2: shared pieces

Each lands with all its call sites moved in the same commit. Where copies have drifted in a
size, colour or spacing, the shared piece takes the most-used copy's values and the difference
is listed as a snap. Where they differ in motion (one fades, one cuts; two curves), the piece
reproduces each site as it is today behind at most one property; if that takes more, the piece
waits for project 2, which settles on one behaviour. So `EmptyNote` lands cutting where its
sites cut today, and `Ripple` waits.

Visuals (`Ui/`):

- `Label`: a `Text` with the shell's font, a size step, a weight and an ink role. The 125 `Text`
  items that style themselves by hand move onto it. Icon fonts, the lock numerals and emoji
  stay plain `Text`.
- `Plate`: the lifted fill with its rest, hover and lit steps and optional hairline (17 sites).
- `FocusRing`: the keyboard ring `ButtonBase` and `Segmented` each draw.
- `IconLabel`: glyph plus label with one ink (also fixes the ink that cuts while its ground
  tints, by tinting both).
- `Card`, `Chip`, `EmptyNote`/`EmptyState`, `TwoLineRow`, `ScrollFade`, `TransportButton`: each
  replaces two to six hand-built copies named in reports 05 to 07.
- `Ring` becomes the one arc (`startAngle`, `sweep`); `GaugeArc` goes.
- `KeyedModel` (the list diff, written three times) and one set of list transitions
  (`ListEnter`, `ListExit`, `ListDisplace`) used by the control centre lists, the launcher and
  Nearby. `Control/KeyedList.qml` moves to `Ui/` on top of them.
- `MinuteClock`: one clock with the refresh nudge, for the five places that build their own.
- `Tile` splits into `ControlTile`, `ChoiceTile`, `CarouselTile` and `DeviceTile` over a shared
  base; callers name the one they use.
- `Icons` and `IconPaths` merge into `Icons`.
- `LoginPill` loses its unused properties and builds only the dot slots it shows.

Pills (`Ui/`):

- `TransientSurface` owns the "may I show" rule: features bind `want`, and it adds focus and
  "no panel open" itself. Its size defaults to the pill row.
- `PillStage` (the centred, snapped content box), `Dwell` (time on screen, pausable, one timer,
  no 100 ms polling) and `swap(fn)` replace the copies in the seven pills.
- Moments: `EdgeTrigger`, `MomentSource.when` and a generic `activities fake <kind>` ipc, so a
  new moment is one short file.

`Reveal`, `Ripple`, `GlyphSwap`/`SwapIcon`, `RollTimeline` and anything else whose point is
motion wait for project 2.

### Phase 3: feature files

Splits along seams the audits named, with no change to what is drawn:

- `Control/`: Wi-Fi, Bluetooth and Audio onto one sub-view skeleton (`ActionRow`,
  `RescanButton`, `NodePicker`, `StreamRow`, `PasswordReveal`); `DisplaysView` into tile, canvas,
  align pad and a pure-JS layout; `HomeView` into tile rows and the notification list; the
  control centre's keys onto `Panel.take`.
- `Calendar/`: grid, day cell, agenda row, day agenda; date helpers into `Services/Calendar`.
- `Launcher/`: scope chip and result item; `RowList` gains the reveal both the launcher and
  the file picker hand-roll.
- `Nearby/`: the panel into send session, send view, receive view and consent cards; the
  picker into header, list and preview; `FileThumb`, `OfferRow`; file-kind helpers to
  `Commons/Files.js`.
- `Phone/`: handset, tile grid, image picker. Tiles stop being rebuilt on every battery change.
- `Power`, `Session`, `Theme`, `Wallpaper`: the wrapper each pair repeats moves into
  `ConfirmGrid` and `CarouselPanel`.
- `Lock/`: `LockView` into view, ground, pill, clock metrics, roll logic, glass-digits wrapper
  and clock plate, moved whole; the thirteen reveal properties become one `reveal` object;
  `Lock.qml` into capture and auth.
- `Bar/`: `Island.qml` into the hover/pin/return state machine, the open card and the drop
  well; the second pill renderer's duplicated formulas into one place.
- Every inline `component` becomes a file.
- Hand-placed x/y layouts become `Row`/`Column` where that reproduces the same pixels; where it
  does not, the numbers stay as locals.

### Phase 4: services

- `Query` (queued process, collected output, stale answers dropped, timeout, logged failure)
  and `PathQuery` replace about 25 hand-rolled process blocks, 12 of which have no failure path.
- `Command` gains `queue` and `coalesce`; Nearby's eight calls, the Brightness and Volume
  throttles and the phone commands move onto it.
- `WatchedFile`; `PolledFile.active`.
- Launcher providers wake on first use, not at shell start. The clipboard list runs only when
  its scope is open.
- Polling: system stats only while the hover card shows, with a read on open so the gauge is
  not blank; charge mode's unused poll goes; the camera scan runs only when a video device
  exists; the recorder uses `processIdChanged`; `PowerProfiles` moves to Quickshell's UPower
  type; the phone satellite does nothing with no phone; the equaliser stops under a covering
  panel and the lock.
- `Commons/Files.js`, `Json.js` (`tryParse`), `Colour.js`, `Zones.js`; `Calculator` splits
  onto the last two.
- `Nearby`, `Phone`, `Rebuild`, `Polkit` split along their own divider comments.
- `Bus`: dead members go and `LockState` moves out. The full split waits for project 3, which
  deletes most of what it holds.
- `shell.qml`: the hand-written ipc handlers that are plain toggles join the generated loop.
- Shader include pre-pass in `tools/qs-shaders.sh`, so the shadow GLSL exists once.

### Phase 5: comments, docs, boards

- Comments by the rule above, file by file, across the tree. History goes (git has it). Essays
  move to `Ui/README.md` or a README beside the feature (`Lock/`, `Nearby/`, `Services/`).
- `Ui/README.md` is rewritten for the new pieces and the relaxed token rule.
- The `.fig` boards take the snaps on all three theme pages.

### Relay files

Project 3 deletes or rewrites these: `Ui/MorphScan.js`, `MorphLayer`, `MorphGhost`,
`MorphPart`, `MorphMask`, `IslandOrigin`, `IslandSurfaceBase`, `IslandSurface`,
`TransientSurface`, `CollapsedPill`, `IslandClock`, `SatelliteLayer`, and the handoff parts of
`Bus`. The clean-up does four things to them and no more:

- removes phase 0's dead code;
- fixes the listed bugs that live there (`Bus.snapTints`);
- makes the few-line mechanical changes a rename or shared piece forces (token names, dropping
  the `Theme.duration()` double wrap, `MinuteClock` in `IslandClock`, `want` and the size
  default on `TransientSurface`);
- nothing else: no splits, no restructuring, no comment pass.

Tokens that only these files read, morph or not, stay in `Timing` and `Metrics` under one
"relay" heading; moving them into files about to be rewritten is wasted work. If the revived
orbit shows an offset bug in the bar or the lock, it is fixed; inside relay logic it is fixed
when the fix is a few lines and reported otherwise. The `spike/stage-handover` worktree is
throwaway and never merges, so it sets no constraint.

## Checking

- Phases 0 (apart from `OledCare`), 2, 3, 4 and 5: harness screenshots equal to a same-conditions
  baseline, apart from the known noise, and `check.mjs` unchanged. A shared piece that settles a
  drift shows that drift and nothing else.
- The lock: its `lockpreview` capture must be identical before and after the `LockView` split.
- What the harness cannot show (populated Wi-Fi and Bluetooth lists, Night Light, power
  profiles) is checked by reading and listed in the hand-over for Ryan to try.
- Phase 1: the token move is checked identical first; then each scale's snaps land as their own
  commit, whose screenshot diff is the list Ryan sees.
- Every phase: both flake checks, and the shell's log free of new warnings.
- Each phase merges to main only after its check, and Ryan restarts and uses the shell before
  the next one starts.

## Left to the builder

- The exact API of each shared piece, within "no more flags than it saves".
- Names of local properties and of the alpha steps.
- Which x/y layouts convert and which stay.
- The order of commits inside a phase.
- Whether a feature's shared numbers warrant a spec singleton or stay as locals.

## Expected result

Theme about 170 members in three files. Roughly 3,000 to 4,000 fewer lines before the handover
project, about 1,000 of them comments. No bug from the list left open without a note.
