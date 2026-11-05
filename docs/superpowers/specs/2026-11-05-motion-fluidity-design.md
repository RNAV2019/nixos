# Shell motion fluidity pass — design

Date: 2026-11-05. Scope: `home/quickshell` (Quickshell/QML shell on Hyprland).

## Intent

Ryan wants every panel animation in the shell to feel more fluid and cost less. That covers
open and close, panel-to-panel handover, in-panel sub-views and controls, transient pills, and
the phone satellite. There was no single complaint behind the request. It is a quality pass,
and Ryan has allowed redesigning transitions where that makes them better.

The machine is a 2880×1800 @ 120 Hz panel at fractional scale 1.333, so anything that only
advances at 60 Hz, sits off the device-pixel grid, or re-renders large textures every frame
shows.

## Goals

1. Everything that moves advances on every frame at 120 Hz. No 16 ms-quantised `SpringAnimation`
   is left for spatial motion.
2. A morph does constant work per frame. Nothing is re-allocated per tick, no content subtree is
   re-rendered because the clip changed size, no layout reflows because a container width animates,
   and no Canvas repaints in software every frame.
3. Shape and contents move as one. Content opacity and offset derive from the shape's progress,
   so an interruption or retarget cannot pull them apart.
4. Panel-to-panel handover keeps momentum. Fast A→B→C switching continues the motion and does not
   stall and re-accelerate from rest.
5. Panel contents stay put while the card uncovers them. Today they ride outward with the card's
   left edge.
6. Text and 1 px strokes stay crisp in motion and at rest: centred content snaps to the device
   grid.
7. The phone satellite is redrawn as one GPU metaball. It must not pop at attach or detach, must
   blend when it switches between following the pill and following a transient, and must sit
   visually above transients.

## Non-goals

- No change to the overall pace. `Theme.morphOmega` stays 21 (~185 ms to 75%, settled ~320 ms).
  Ryan chose this.
- No overshoot anywhere except the phone satellite, which keeps ζ 0.7. Ryan A/B-tested overshoot
  on 2026-10-18 and rejected it.
- Launcher result rows keep their fade-in on keystrokes. Ryan chose this. Only smooth it, for
  example the scroll (`contentY`) retarget.
- No new features and no layout or colour changes beyond what the motion needs.

## Anti-goals (a failure even if it technically works)

- Brings back the blank-frame or flash-of-bare-wallpaper problems fixed in the 2026-10-18 handover
  overhaul. The presented-frame handshake (`IslandOrigin.presented`, `Bus.islandPresented`, the
  still and ground fade) must keep its guarantee.
- Visible softness or shimmer on text at rest. A shader clip that resamples content is worse than
  today.
- Any overshoot on surfaces.
- Breaks `Theme.reduceMotion`, the lock snapshot settle (`Bus.lockHeld`), or the parked-window
  memory trade.
- Breaks keyboard or focus behaviour in panels (see `Ui/README.md` key rules).

## Decided by Ryan (2026-11-05)

| Question | Answer |
|---|---|
| Overall feel | Builder's call → keep pace; gain fluidity through the fixes |
| Scope | Open/close, panel-to-panel, phone satellite, in-panel and pills |
| Depth | Everything, including transition redesigns |
| Content during open | Stays put and is uncovered by the growing card |
| Content fade | Driven by shape progress, not fixed timers; tuned to feel as snappy as today |
| Fast handover | Carry velocity through |
| Phone satellite | Shader (SDF metaball) rewrite, same ζ 0.7 |
| Sub-views in Nearby, Phone, ConfirmGrid | Slide like the control centre: drill-in to the left, back to the right |
| Launcher rows | Keep the fade-in |
| Pace | Keep `morphOmega` 21 |

## The work, by area

Line references are from the 2026-11-05 audit and may have drifted.

### A. Per-frame springs everywhere (judder at 120 Hz)

`SurfaceSpring` and `MicroSpring` wrap `SpringAnimation`, which integrates in fixed 16 ms steps.
At 120 Hz that moves on every other frame. QML cannot subclass `Animation`, so a `Behavior`
cannot host the per-frame `MorphSpring` (a `QtObject` with `target` and `value`). The existing
pattern is to bind through the spring, as in `Bar/Island.qml` (`implicitWidth: widthSpring.value`).

Users to migrate:
- `Control/ControlCenter.qml`: home and sub-view slides. Use one progress spring (0..1) driving
  both x values, so they share one clock and one velocity.
- `Ui/CarouselRow.qml` rail x, and the `Ui/Tile.qml` geometry Behaviors.
- `Ui/Segmented.qml` plate x and width. Same ω for both, so the edges land together.
- `Ui/Switch.qml` knob, and `Control/MediaCard.qml` thumb scale.
- `Nearby/NearbyPanel.qml` tile-row x.
- `Bar/Widgets/Workspaces.qml` pill width and dot width.
- `Control/DisplaysView.qml` monitor tiles: four springs, one per x, y, w and h.

Spring parameters:
- Spatial users take `morphOmega`, critically damped.
- Micro users get a micro omega token, chosen to match today's settle time without overshoot.
- Unit-range springs set their own `epsilon` (about 0.001).

Once the users are gone, retire `SurfaceSpring` and `MicroSpring` and their Theme tokens. A
small helper is the builder's call. It could be a `MorphSpring` preset, or a pattern documented
in `Ui/README.md`, for example `ProgressSpring`: a 0..1 spring on a bool or index.

### B. Surface morph cost and the reveal (`Ui/FrostedSurface.qml`, `Ui/IslandSurfaceBase.qml`, `Ui/Panel.qml`)

Today `contentHolder` has `layer.enabled` and a `MultiEffect` mask, and `mask` is a layer too.
Both fill the surface, whose size changes every tick, so the textures are re-allocated and the
content re-rendered every frame. `Panel` is `openWidth` wide at x=0 of a card growing from its
centre, so contents ride the left edge.

Target:
- Content is laid out once at the open size and placed at a fixed, device-snapped offset that
  centres it on the final card. The growing shape uncovers it, and nothing inside moves while the
  card morphs.
- The rounded clip is analytic. One candidate is a `ShaderEffect` over a fixed-size
  `ShaderEffectSource`, clipping to a rounded-rect SDF with size, radius and offset as uniforms;
  this needs `qsb` in the build. The builder may pick another mechanism that keeps texture size
  constant during a morph.
- Content textures are sampled 1:1 on the device grid, so there is no resampling softness.
  Rasterising at the open size times the device ratio is the builder's call.
- The same applies to transient pills, which already lay out at final size by README rule, and to
  the held still.
- Centred children that compute `(win.surface.width - width) / 2` (in `Osd`, `SharingPill`,
  `Moments`, `RecordingFailedPill` and `DictationPill`) move to the static centring, or at least
  through `snap()`. `DictationPill` stops binding its row width to `surface.width`.

### C. One clock for shape and contents (`IslandSurfaceBase.qml`, `CollapsedPill.qml`)

Replace the `bodyHolder` opacity Behavior (PauseAnimation plus Morph on fixed durations) with a
pure function of the shape spring's progress. Progress is the normalised height and width between
the from and to shapes.

- Open out of the pill: contents reach full opacity well before the shape settles. They should
  feel as quick as today's 50 ms.
- Panel to panel: the entering contents start late in the progress, as today's 45 ms delay does,
  and keep the `enterTravel` settle along the height's direction, now also progress-driven.
- Close: contents are gone early in the progress.
- The collapsed pill's clock and marks fade in tied to the same progress on close. They do not
  use a 50 ms timer.

The curve shapes and thresholds are the builder's call. Tune them on video against today's look.

### D. Momentum through handover (`IslandOrigin.qml`, `IslandSurfaceBase.qml`, `Commons/Bus.qml`)

Today `hold()` snaps the still's springs (velocity 0), and the taker starts from rest once it has
presented. Instead:

- Publish velocity with the handoff, alongside shape, radius and duration.
- The taker seeds its width and height springs with that velocity.
- The still keeps advancing along a spring toward the taker's target while it waits for the
  taker's first frame, so the two meet in step.

The presented-frame guarantee must hold: the still stays until the taker has a frame on screen.
The radius on a held still also springs, so it does not jump when `held` toggles.

### E. Warm windows and settle tail

- Warm every island surface once, staggered, after the session is ready. Each window then makes
  its first frame in the background, and the first open after login does not hold the pill for
  about 250 ms.
- Consider raising `surfaceRetain`. Whether to and by how much is the builder's call; the cost
  is about 8 MiB of GPU memory per window, roughly 100 MB of RSS in total.
- Raise `MorphSpring`'s rest epsilon for pixel springs to about 0.3 logical px (under half a
  device pixel), so windows stop rendering ~0.4 s after motion looks done. This must not visibly
  snap.
- A rapid re-toggle within a short grace after close should not pay the sliver-to-full resize
  again. Optional; builder's call.

### F. Input regions during motion

`Region { item: surface }` on transients and the satellite's hit region changes every tick.
Use the final shape's region, set once it is known, or no card input while the morph runs. The
choice must keep click-off-to-dismiss and the pills' input behaviour unchanged at rest.

### G. In-panel choreography

- **Sub-views slide.** The Nearby, Phone and `ConfirmGrid` sub-view switches become a horizontal
  slide on a shared progress spring, like the control centre after A: drill-in to the left, back
  to the right. A sub-view whose card height changes keeps the card's height morph.
- **Async loads.** The control-centre sub-view `Loader` is `asynchronous`. The slide must not show
  an empty or half-built column: start it on `loaded`, or hold until the item exists.
- **Moments.** `Activities/Moments.qml` swaps with a sequential fade out, swap, fade in; an
  interruption jumps to the end. Make it retarget, gated on opacity, tied to the shape per C where
  that applies.
- **Toast.** The fade is the same in and out. Exit should be faster than enter, and both should be
  tied to the rise spring.
- **WifiView.** The password row animates `height` inside a column. Spring the height, keep the
  content at a constant size, and clip it.

### H. Per-frame waste in widgets

- `Dictation/DictationPill.qml`: the bar heights have a 60 ms NumberAnimation restarted by about
  30 Hz level updates, so they never settle. Use a high-ω per-frame spring per bar, or low-pass
  the level and bind it directly.
- `Control/MediaCard.qml`: the hills Canvas `requestPaint()` runs every frame while music plays,
  a software repaint. Move it to the GPU (a ShaderEffect with a phase uniform, or a Shape).
- `Bar/Widgets/MiniCalendar.qml`: animates `font.pixelSize`. Use a fixed size and animate `scale`.
- `Ui/ScrollView.qml`: the thumb follows content through a restarted Morph. Bind it directly.
- `Launcher/Launcher.qml`: the scroll Morph restarts per key. Use a per-frame spring on `contentY`.
  The row fade-in stays.
- Hard-coded durations go to named Theme tokens through `Theme.duration()`, which keeps reduce
  motion working. These are in Dictation, `Tile.qml:402`, `PhonePanel.qml:347`, Nearby and
  `LoginPill`.

### I. Phone satellite rewrite (`Bar/PhoneSatellite.qml`, `Bar/Bar.qml`)

Keep:
- the geometry model, where the disc is `edge + f(p)`, an offset rather than a chaser;
- the ζ 0.7 spring;
- the lock behaviour (`wantOut` with `sessionReady || locking`, `Bus.lockHeld` settle);
- the follow targets: pill, hover card, transients;
- the retract for full panels.

Change:
- **One SDF shader.** Draw the bud, bridge and stubs as one fragment shader: two rounded shapes
  joined by a smooth-min. That replaces the per-frame SVG strings re-parsed into up to five
  `PathSvg` paths. Fill and outline must match the pill's stroke and colour tokens, and edges must
  be exactly antialiased.
- **Continuous detach.** The neck and stubs come from `p` and the gap continuously, with no
  `nub` NumberAnimation, no velocity test and no hard `attached` or `inside` thresholds. This
  removes the half-pixel pop and the threshold flicker.
- **Blended follow-target switch.** When the target changes between pill and transient, the edge,
  top, height and cap-radius jump. Bleed that out with a per-frame spring on the delta.
- **Unsnapped edge.** Read the pill edge from the unsnapped spring geometry, not
  `snap(x) + snap(width)`, which jitters by up to 1 device px. Make sure the join still meets the
  pill's drawn outline.
- **Rest on the grid.** The disc centre snaps to the device grid at rest, while motion stays
  unsnapped. The handover between the two must not visibly jump.
- **Above transients.** Transients are in the Overlay layer and the satellite is in the Top-layer
  bar window, so today the bridge is drawn under the transient's outline. The bud must render
  above, or as part of, the transient while it is followed. How (a satellite instance in the
  transient window, or a shared component) is the builder's call.
- **Defer the panel request.** `Bus.toggleSurface("phone")` is called from inside the spring's
  frame handler. Defer it with `Qt.callLater`.
- **Shape bounds.** Size the shader or Shape to the bud's bounds, not the whole bar window.

## Constraints

- Follow `home/quickshell/Ui/README.md`. New shared motion pieces go in `Ui/` with a header
  comment and a README entry, and the README's "Motion and colour" section is updated.
- Colours come from Theme tokens and `palettes.json`, with no literals. Durations are Theme
  tokens and go through `Theme.duration`. `reduceMotion` must keep working everywhere.
- Shaders are the first in the shell; nothing uses `ShaderEffect` or `qsb` yet.
  `~/.config/quickshell` is a live out-of-store symlink to `home/quickshell`
  (`home/desktop.nix:537`), so **Ryan's choice**:
  - Compiled `.qsb` files are committed beside their `.frag`/`.vert` sources, for example under
    `home/quickshell/Shaders/`.
  - A regen script (with `qsb` from nixpkgs `qt6.qtshadertools`, run through `nix shell` or
    `nix run`) rebuilds them.
  - A check fails when a `.qsb` is stale against its source, in the same style as the repo's other
    format checks.
  - Hot reload and the harness load shaders straight from the checkout.
- The shell must still hot-reload, or the docs must say which change needs a restart. Ryan
  restarts the shell outside the T3 sandbox (see memory).
- The frost is Hyprland's layer blur behind the window (`home/desktop.nix:433`), not a shader in
  the shell. The content clip therefore only has to clip the shell's own drawing.
- Formatting and lint checks per repo conventions (`qmlformat` or the repo's checker).
- Never restart or reload Ryan's live shell from inside the T3 Code sandbox, because the lock
  screen cannot authenticate then. Test in the headless harness or in nested Hyprland.

## Verification

- **Static and screenshot:** `tools/qs-verify` (`run.sh`, `shoot.sh`, `compare.sh`) with
  `QS_THEME=ariadne`. Compare against a pure-main run made in the same conditions, not only the
  stored baseline (see the timing artifacts in memory). At-rest screenshots should be unchanged,
  except intentional crispness gains and the satellite redraw, which is reviewed by eye.
- **Motion:** rebuild the nested-Hyprland motion recorder. The recipe is in memory
  (`qs-verify-timing-and-motion`): wf-recorder lossless at 60 fps headless, per-frame silhouette
  analysis. Record main and the branch. Check:
  - no new blank or bare frames at handover;
  - shape trajectories match main (same pace);
  - content and shape move in step;
  - an A→B→C rapid switch shows no stall;
  - the satellite has no pops.
  A 120 Hz capture, if achievable headless, is better for the spring-quantisation fixes.
- **Perf:** compare frame time or GPU time during an open on main and on the branch, using
  `QSG_RENDER_TIMING=1` or Qt's scene-graph render timing in the harness. Report the numbers.
- **Ryan:** final A/B on the real machine before merge. Ryan restarts the shell.

## Calls made by Claude (from the builder check; Ryan to confirm on review)

- **Clip memory against crispness.** Crispness wins. The fixed content texture is the open card's
  size times the device ratio, about 1.5 MB for a 520×400 card, which is negligible.
- **Click during a morph.** Input behaves as at rest from the first frame. The region is the
  *final* card shape at once, so a click off the card while the card opens still dismisses it.
- **Handover velocity rule.**
  - Velocity is carried per axis.
  - On an axis where the carried velocity points away from the taker's target, that axis starts
    at zero velocity. It is not reversed.
  - On an axis where it points toward the target, it is clamped to what a critically damped
    spring could have at that distance, so it cannot overshoot.
  - Result: no overshoot, no stall.
- **Progress for content fades.**
  - Use the axis with the larger travel.
  - If neither axis travels (the same size, only the contents change), fall back to a short
    progress spring of its own.
  - On a retarget, re-base from the current shape, but carry the current opacity: opacity only
    moves monotonically toward its new end, so it never jumps.
- **Perf bar.**
  - Per-frame render time during a morph must not regress anywhere, and should drop for panels.
  - Extra memory up to about 30 MB for warmed windows is acceptable.
  - Report numbers from before and after.
- **Satellite across windows.** The bud is drawn by whichever window it is following. During the
  hand-off between the bar and a transient, a one-frame draw in both is acceptable. A gap is not.
- **120 Hz verification.** Try a headless 120 Hz nested output first. If that fails, log each
  frame's spring values and timestamps (debug env var) and check that the values change on every
  frame. Ryan's eye on the real machine is the final check.

## Left to the builder

- The helper and component shape for per-frame springs, and the micro omega value.
- The clip mechanism, if the shader approach meets a snag, as long as texture size stays constant
  and content is crisp.
- The progress-to-opacity curves and thresholds.
- How the satellite renders above transients.
- Whether to raise `surfaceRetain`, and the rapid re-toggle grace.
- Commit granularity. Work happens in a git worktree on a branch, and areas land as separate
  commits so any one can be reverted.
