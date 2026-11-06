# Ui

The shell's shared pieces: what a surface, a panel, a pill, a control and a motion are made of,
and the contracts the services in `Services/` follow. Each file opens with a comment saying what
it is for; this is the map, so you find the right one before drawing your own.

Imports: `qs.Commons` for `Theme`, `Bus`, `Icons`, `IconPaths`, `Paths`; `qs.Ui` for what is
below; `qs.Services` for the services.

## Surfaces

Everything that grows out of the island is a window of one of two kinds, both on
`IslandSurfaceBase` (the layer-shell window, the shape springs, the still left behind, the
handover to another surface). It must be the delegate of a `Variants { model: Quickshell.screens }`,
so there is one per output.

**Contents are in a fixed box.** Whatever a surface holds is laid out at the open size
(`openWidth` x `openHeight`) in a box that never changes during a morph, centred where the open
card will sit (`win.contentBox`, `FrostedSurface.contentWidth/contentHeight`). The growing card
uncovers the contents and does not move them: `FrostedSurface` renders the box to a texture
(1:1 with device pixels, so it is crisp at rest) and crops it to the card with
`Shaders/roundedclip.frag`. So contents never bind to `win.surface.width` or `.height`, which
is the moving card; they take their size from the box (`parent.width`) or from the open size.
Only the open size changing (a panel gaining a row) re-allocates the texture. Things that are
the surface's own size, like the shut pill carried over, go in `FrostedSurface.fillData`.

**Contents fade on the shape's clock.** `IslandSurfaceBase.morphProgress` is how far the shape has
travelled from the shape it left (re-based on every retarget) to the one it is going to, along the
axis that travels further (`Motion.progress`; a short spring of its own when neither does). The
contents' opacity (`bodyOpacity`) and the collapsed pill's share while closing (`pillAmount`) are
smoothsteps of it over the `Theme.fadeOpenIn`, `fadeEnterIn`, `fadeCloseOut` and `fadePillIn`
ranges, with no timers. A retarget carries the opacity and it only moves toward the end its intent
points at. A held still is cut instead (its own two fades). `CollapsedPill.progressDriven/amount`
take the pill's clock and marks off their timed fade while closing.

- **`IslandSurface`**: a panel the user opens. A key on the bus toggles it, it takes the
  keyboard, a click off the card closes it, and Escape closes it unless the contents take the key
  first. Give it `key`, `openWidth`, `openHeight`, `openRadius` and a body (a `Panel`).
  `focusTarget` names the item that takes the keyboard on open (a text field); `passThrough`
  narrows the input region to the card; `wanted` lets an owner (the polkit prompt) open it.
- **`TransientSurface`**: a pill that opens by itself. Bind `wanted`; it grows out of the
  island, takes its turn by `rank` and melts back when `wanted` drops. `cardInput: false` makes
  the window click-through. It never takes the keyboard. Ranks in use: OSD 4, dictation 3,
  sharing request 2, notification toast and attention moment 1, sharing progress, informational
  moment, rebuild and a failed recording 0. One that is outranked waits, and takes over as a
  handover when the higher one lets go.

`IslandSurfaceBase.overlayData` takes items drawn over the card and outside its clip, in the window's
coordinates: the one user is the phone satellite (`Ui/SatelliteLayer.qml`), drawn there while it rides
a transient so its neck lies over the transient's outline (`Bar/PhoneSatellite.qml` writes its geometry
to `Bus.satellite[screen]`; the body is the one shader, `Shaders/satellite.frag`).

Both register on `Bus` when they are created (`registerSurface`), so there is no list to edit.

**To add a panel:** a file with a `Variants` over `IslandSurface { key: "name" ... }`, an
instance in `shell.qml`. The `qs ipc call name toggle|close` handler comes from the loop over
`Bus.islandKeys`, unless the key is in that filter, which is for panels with handwritten
handlers (recorder, theme, session, nearby, auth).

**To add a pill:** a file with a `Variants` over `TransientSurface { key, rank, wanted,
openWidth/Height/Radius }`, an instance in `shell.qml`. Lay its contents out at their final size
in an `Item` centred in the content box (`x: (parent.width - width) / 2`), so the growing shape
uncovers them. `wanted` should also check `win.focused && !Bus.islandOpenFor(win.screenName)`
where the pill should not cover an open panel; see `Rebuild/RebuildPill.qml`, the simplest
one. Count the dwell on screen only (`Timer { running: win.open }`).

## Panel scaffolding

- **`Panel`**: the contents of a panel: optional header (`title`, `meta`, `hasBack`), body,
  optional footer (`footerShown`), and the keys every panel shares. Needs `surface`.
- **`PanelHeader`**, **`PanelFooter`**: what `Panel` builds its header and footer from; reach
  them through `header`, `headerActions` (controls for the header's far end) and `footer`.
- **`Divider`**: the hairline between sections; you set its length, `vertical` and `alpha` if it
  must be quieter.
- **`SectionLabel`**: a section's heading with an optional `detail`, `note` and one accent
  `action` link.
- **`CarouselPanel`**: the theme and wallpaper pickers: a row of carousel `Tile`s (`CarouselRow`)
  with a footer. You give `entries`, `current`, a `tile` Component and what `chosen` does.
- **`ConfirmGrid`**: a row of `ChoiceTiles` that does one thing once the card has gone; a tile
  with `confirms` arms on the first press. The power menu and the profiles card.
- **`ChoiceTiles`**: the one-of-three grid itself (also the recorder picker's capture row).
- **`RowList`**: a `ListView` that scrolls only once its rows overflow; **`ScrollView`** is a
  wheel-stepped `Flickable` for a body taller than the card (`scrollable`, `wheelStep`); its thumb is
  bound straight to the view, so it never trails the content.

The key rules, all in `Panel.take`:

- Escape backs out of a sub-view if `backKeys` (true where `hasBack`, or where a step back has
  no button, such as an armed tile); otherwise it falls through to the surface, which closes.
- Backspace goes back only where `backKeys` says there is a back, and does nothing elsewhere.
- Arrows and h, j, k, l emit `moved(dx, dy)`, Tab and Shift+Tab `stepped(delta)`, Return, Enter
  and Space `activated()`; each only if `takesMove`, `takesTab` or `takesActivate` is set.
- A key the panel does not take reaches `keyPressed`; accept what you use. Content items that
  hold focus pass on what they leave unaccepted (`contentKeyTargets`).

## Island content

- **`IslandPill`**: one 42 px row in one of eight `layout`s: `glyphTrackReading`,
  `glyphLabelTrackReading`, `glyphLabelReading`, `glyphTrackReadingAction`,
  `glyphWaveformReadingAction`, `glyphLabelAction`, `glyphLabelDetailReading`,
  `glyphLabelDetailDots`. The glyph is the item you put inside it; `label`, `detail`, `reading`,
  `value`, `alert` (outline in love) and `tabularReading` are the rest. Layouts and metrics are
  the board's `Island pill` set.
- **`PillState`**: one state's contents in a pill that has several; they cross-fade, and a
  hidden one takes no input.
- **`LevelTrack`**: the groove and fill, 0..1; `indeterminate` slides a segment while the total
  is unknown.
- **`Ring`**: a circle's progress, `value` 0..1 from twelve o'clock; **`Spinner`** is a
  quarter of one turning.
- **`PillMarks`**, **`IslandClock`**, **`RollingClock`**, **`CollapsedPill`**: the shut pill and
  what it carries over to a surface. You only touch these for the pill itself.
- **`LoginPill`**: the lock screen's and the polkit prompt's pill.

## Controls

All pressable controls are on **`ButtonBase`**: hover and press tracking, the press scale,
`enabled: false`, Space and Enter, an accessible name and the keyboard ring.

- **`Button`**: `kind` (`Icon`, `Disc`, `DiscDanger`, `Neutral`, `Primary`, `Danger`, `Ghost`,
  `Plain`, `OnAccent`, `Tonal`, `Inverse`) and `size` (`Compact`, `Regular`, `Large`); `text`,
  `icon`.
- **`Segmented`**: a track with a sliding plate; `segments` of `{ label, icon, enabled }`,
  `currentIndex`, `chosen(index)`; `fit` and `compact` are the narrow forms; `pending`.
- **`Switch`**: `checked`, `toggled(value)`.
- **`TextField`**: `kind` `Panel` (on a ground) or `Bare`; `accepted`, `cancelled`, `keyPressed`.
- **`Tile`**: `kind` `Control` (pill with a badge; `stacked` puts the badge above the words for a
  narrow cell, as in the phone panel), `Choice` (square one-of-three), `Carousel`
  (picture with a ring), `Device` (disc with a progress ring); `active`, `current`.
- **`ListRow`**: `kind` `Grouped` (control centre pill; `groupPosition` rounds a stack's outer
  corners), `Hairline` (the board's row) or `Flat` (the file picker's). Lead `glyph`, `label`,
  `sublabel`, `value`, and `trailing` for the far end; other children are placed by hand. Pass
  `interactive: false` for a row that only reports.
- **`RoundedClip`**: crops its children to a rounded box. Under a fractional scale it must sit
  on the device-pixel grid (`FrostedSurface.snap()`).
- **`StrokeIcon`**: draws one icon. `path` is a Material Symbols Rounded name (drawn from
  `Theme.iconFont`) or 24-grid SVG path data. `Commons/Icons.qml` holds the names the shell
  uses, `Commons/IconPaths.qml` what `StrokeIcon` is given (names, plus the few marks Material
  lacks as paths). A name the font lacks shows as its letters, so check a new one.

**The recipe, on `ButtonBase`:** hover steps `highlightMed` from `groundRestAlpha` to
`groundHoverAlpha` (tiles and grouped rows from `surfaceRestAlpha`); filled kinds lift by
`fillLift`; pressed scales by `Theme.pressScale`; disabled is the same control at
`Theme.disabledAlpha`, rasterised so overlapping glyphs dim evenly; the ring shows only for a
focus that arrived by Tab. Do not hand-roll these; if a new control needs a state, it goes in
`ButtonBase` or the primitive.

## Motion and colour

- **`SatelliteShape` / `SatelliteLayer`**: the phone satellite's drawing. `SatelliteShape` is the
  ShaderEffect for `Shaders/satellite.frag` (pill cap and disc, smooth union, 1 px outline; properties
  are the shader's uniforms in the parent's coordinates). `SatelliteLayer` adds the disc's face and the
  hand-over protocol: a host (the bar, or a transient's window via `overlayData`) claims the satellite
  with `wanted`, and the host giving it up keeps drawing until the taker's frame is swapped
  (`Bus.claimSatelliteHost`), with `Theme.morphPresentFallback` as the bound. Geometry comes from
  `Bus.satellite[screen]`, written by `Bar/PhoneSatellite.qml`.

- **`MorphSpring`**: the island's shape spring. Critically damped, solved exactly per frame so
  it lands on one curve at any refresh rate, and a new `target` keeps the velocity. Bind
  `target`, read `value`; `animate: false` snaps. `damping` below 1 overshoots; only the phone
  satellite asks for that.
  `kick(v)` sets a starting velocity; `label` names it in the motion log (`QS_MOTION_LOG=1`, read by
  `tools/qs-verify/motion`), one unique label per instance. `Motion.js` holds the maths
  (`springStep`, `seedVelocity`, `progress`, `ramp`, `snap`).
- **`ProgressSpring`**: a `MorphSpring` for a 0..1 progress (`ProgressSpring { target: shown ? 1 : 0 }`);
  `omega: Theme.microOmega` gives the small controls' shorter pace.
  In-pill choreography uses them too: a moment swap (`Activities/Moments.qml`, `Theme.momentFadeOmega`;
  the contents change at `Theme.momentSwapOpacity`), a toast slot's presence (`Notifications/Toast.qml`;
  out, the opacity is spent over the first 0.3 of the travel), the Wi-Fi password row's height
  (`Control/WifiView.qml`, content kept at 40 px inside a clip) and the dictation level bars
  (`MorphSpring` per bar, `Theme.levelOmega` 40, epsilon 0.1 px).
- **`SubviewSlide`**: the control centre's slide between a panel's home view and one sub-view
  (drill-in left, back right, no cross-fade), one `ProgressSpring` carrying both. It owns the two
  views' `x` and `visible`; `subReady` makes it wait for a Loader; `name` labels it in the log.
  Used by the control centre, Nearby (send/receive and the picker) and the phone panel.
- **Shaders** (`Shaders/*.frag`, each with a committed `.frag.qsb`): `roundedclip` crops a
  surface's fixed content box to the moving card (`boxSize`, `boxOrigin`, `itemSize`, `radius`,
  `aa`), `satellite` draws the phone satellite, `hills` the media card's waves on the GPU.
  After editing a `.frag`, run `tools/qs-shaders.sh` (regenerates the `.qsb`); `tools/qs-shaders.sh
  --check` and the flake check `quickshell-shaders` fail when one is stale. A new shader gets a case
  in `tools/qs-verify/motion/shader-smoke.sh`.
- **`Morph`**: a `NumberAnimation` for state changes that are not spatial (fades, fills).
- **`ContentFade`**: the `Morph` for a cross-fade between two contents in one place (the shut
  pill and the open card, one panel view and the next).
- **`Tint`**: a `ColorAnimation`, so colour never overshoots.

All of them follow `Theme.reduceMotion` (`QUICKSHELL_REDUCE_MOTION=1`): the springs snap, the
satellite included, and no motion label runs past 80 ms (`record.sh ... reduce`, then
`check.mjs OUT/reduce --max-anim-ms 80`). A raw duration goes
through `Theme.duration(ms)`, which shortens it then; the named ones (`morphState`, `tintFade`)
already do.

## Services

The contracts a service file follows; a singleton file takes the contract as its root type.

- **`LevelSource`**: one adjustable level the OSD shows. `value` 0..1, `available`, `glyph`,
  `reading`, `stateOnly`, `alarming`, `adjusted(pressed)`; `step(up)` and `set(v)`. Brightness,
  Volume, Microphone and KeyboardBacklight.
- **`Job`**: work with an end that the shell reports. `phase` (`""`, running, done, failed),
  `done`/`total`, `startedAt`/`endedAt`, `fraction`, `dismiss()`. `Rebuild`.
- **`Stream`**: a long-lived stream of lines from a command or socket, restarted with backoff
  while the daemon is away. `command` or `socketPath`, `line(text)`, `connected`, `errText`.
- **`Command`**: a one-shot `Process` whose failure is logged and raised. `exec(args, undo)`
  starts it unless one is running; `undo` runs if it fails, so the screen goes back to what is
  true. `errText`, `failed(code, message)`, `logFailures`.
- **`StampedProcess`**: a process that knows when its answer is stale (`stamp` against
  `launchedFor`). **`QueuedProcess`** adds `run()`, which queues exactly one more run behind
  the current one.
- **`PersistedValue`**: a small string kept in `Paths.stateDir`. `name`, `value`, `save(text)`,
  `restored(text)`, `loaded`.
- **`PolledFile`**: a `FileView` re-read every `interval`, for procfs and sysfs files no watch
  can follow.
- **`Provider`**: a launcher provider's base. `section`, `prefix`, `results`, `emptyResults`,
  `activate(row, modifiers)`; the row shape and the scope rules are in `Services/Omnibox.qml`.
- **`Activities/MomentSource`**: one source of moments. `kind`, `show(spec)`, `withdraw()`,
  `queued()`, `dismissed`; the spec is in `Services/Activities.qml`, and a source is listed in
  `Activities/ActivitySources.qml`.

## Rules

- **Tokens live in `Commons/Theme.qml`.** A number or a role colour that two files need goes
  there, with a comment. Colours come from `Commons/palettes.json`, which every other program's
  theme is generated from too; Theme reads it live.
- **The boards come first.** Design in `~/Designs/NixOSQuickshell.fig` (three pages, one per
  theme, with variant sets built on the primitives above), then implement from it.
- **No inline `component` declarations.** They break hot reload and cannot see their file's
  ids. A new type is a file of its own, in its feature's directory or, once two features use
  it, in `Ui/`.
- **Match the neighbours.** Short comments that say why, in full sentences; 2-space
  `qmlformat` (`nix build .#checks.x86_64-linux.quickshell-qmlformat`).
- **Verify with `tools/qs-verify`** (see its README): it runs the shell headless in its own
  sway and compares screenshots against a baseline. Set `QS_THEME=ariadne` so the capture does
  not follow the live theme, and a `QS_VERIFY_WORK` of your own so two runs do not share a
  directory. Never restart the live shell, and never edit the main checkout (it is what the
  live shell runs).
