# qs-verify

A headless screenshot harness for the Quickshell config in `home/quickshell`. It runs the shell
in its own sway, captures one PNG per surface and state, and compares two captures pixel by
pixel, so a refactor that should change nothing can be shown to change nothing, and one that
should change something shows exactly where.

It never touches the live session: its own compositor, `XDG_RUNTIME_DIR`, `HOME` and every
`XDG_*`, two private dbus-daemons (session and system), a private PipeWire. Nothing is written
to the real state, cache or cliphist, and the live shell is not restarted. Any config dir works,
even the live one: it is only read, and the patches go on a copy.

```sh
tools/qs-verify/run.sh home/quickshell            # start (a copy of the config, patched)
tools/qs-verify/shoot.sh /tmp/shots-new           # ~6 minutes, one PNG per state + meta.txt
tools/qs-verify/compare.sh BASE_DIR /tmp/shots-new [ALLOW_FILE]
tools/qs-verify/restart.sh                        # quit and restart the shell on the same state
tools/qs-verify/stop.sh                           # tear everything down
```

`QS_SCALE=1.25 run.sh ...` runs the fractional-scale scenario (compare only against a baseline
taken at the same scale; `compare.sh` refuses otherwise). Smoke-tested for five states; a full
1.25 baseline has not been taken. `QS_THEME=dark` picks a theme other than
the live one (default: copied from `~/.local/state/theme/name`). `QS_VERIFY_WORK` moves the work
directory (`/tmp/qs-verify-$USER`) to run two harnesses side by side. `QS_SHOOT_ONLY=NAME` captures
one state (into an existing OUT_DIR). `shoot.sh` refuses a harness that has already been shot:
notification history, backlight and other state carry over, so every capture run is
`stop.sh; run.sh; shoot.sh`. `run.sh` exits 2, leaving the harness up, if quickshell logs a warning at load that
is not in `allowed-log.txt`.

A baseline for the commit the work started from lives at `~/.cache/qs-verify/baseline-<sha>/`.
A phase of work shoots its own worktree and compares:

```sh
tools/qs-verify/run.sh home/quickshell && tools/qs-verify/shoot.sh /tmp/phase-1 \
  && tools/qs-verify/compare.sh ~/.cache/qs-verify/baseline-c47ce76 /tmp/phase-1 allowed.txt
```

Diff images (red where the pixels differ, over the faded original) go to `NEW_DIR/diff/`.

## What is covered

- Resting island, and the pointer over the island and over the workspaces pill.
- Every island panel: launcher (empty, a query, the calculator), control centre (home, keyboard
  focus ring, and its Wi-Fi, Audio, Bluetooth and Displays views), calendar, nearby (empty, with
  peers, receive view, with an arrival), session, profiles, theme, wallpaper, recorder.
- The auth prompt, through the `authpreview` ipc stage: pkexec, plain, long name, several
  identities, typing, checking, wrong password.
- OSDs: brightness, keyboard backlight, volume, volume muted, mic on, mic muted.
- Rebuild pill: evaluating, building (5 of 12, and builds with fetches), done, failed. Its track
  and percentage are a time estimate, so they are masked.
- Recording-failed pill: the picker starts a capture and a stub `wl-screenrec` fails.
- Dictation pill: listening before the mic is up, listening with level bars, live text,
  transcribing, polishing.
- Sharing pill: connecting, offer, receiving, saved.
- Moments: plugged in, Wi-Fi sign-in.
- The keybinds cheatsheet, alone and over an open control centre.
- Notification toasts: basic, critical, long text; the control centre's notification list.
- The phone (last, so nothing before it sees it): the satellite docked, hovered, on a low battery
  and riding the volume OSD, and the phone panel at rest, with the pointer over a notification and
  ringing, with low battery, with mobile off, after Browse is refused (the note), with the wallpaper
  picker on the phone's storage, on the laptop and with no file access, and with a chosen wallpaper;
  the satellite beside the open hover card; and Nearby over KDE Connect (choose files, sending with
  and without a reading, sent, no phone, receiving) with the sharing pill receiving and saved. The
  mock plays kdeconnectd's job tracker through the bridge's `org.kde.JobViewServer`, and two checks
  (not screenshots) confirm Browse starts `nautilus` on the mount and that choosing a wallpaper
  leaves exactly one copy in the state dir.

- What is playing (last of all, with the phone gone again, so no state above is taken in another
  order than before): the hover card with a player and the weather (playing, paused) and with
  nothing playing, the Now playing panel (playing, paused), and the control centre with its media
  card (paused; its notification list is masked). The playing panel's equaliser and scrub bar
  are masked.

## How states are driven (no QML hooks)

| State | Driver |
| --- | --- |
| panels | `qs ipc call KEY toggle` |
| control centre views | real keys through `wtype` (Tab to the tile, Return) |
| OSD brightness / keyboard | the fake sysfs files the shell reads (bind-mounted over `/sys/class/backlight` and `/sys/class/leds` for quickshell only) |
| OSD volume / mic | `wpctl` against a private PipeWire + WirePlumber with a null sink and source |
| rebuild pill | JSON lines appended to `$XDG_RUNTIME_DIR/rebuild.jsonl`, nix `internal-json` style, with a live `sleep` standing in for the nix process |
| recording-failed pill | a stub `wl-screenrec` on PATH that prints an error and exits 1; the picker's Return starts the capture |
| dictation pill | JSON lines through a `socat` listener on `$XDG_RUNTIME_DIR/handy/overlay.sock` |
| sharing pill, nearby panel | a stub `nearby` on PATH replaying `nearby.events` (peers, status, transfers) |
| moments | the shell's own `activities` ipc (`plug`, `wifi`) |
| keybinds cheatsheet | `qs ipc call keys open`, as Hyprland does while AltGr is held; its lines are the installed `keys.json`, or `QS_KEYS_DATA=FILE run.sh ...` for a config not yet switched to |
| calendar agenda | off by default (the stub `ical-agenda` fails as on a fresh machine); put ical-agenda's own tab-separated output in `$QS_VERIFY_WORK/cal-events.tsv` after `run.sh` and press `r` in the panel |
| auth prompt | the shell's own `authpreview` ipc |
| toasts | `env -u LD_LIBRARY_PATH notify-send` on the private session bus |
| what is playing | `mock-mpris.py`, an MPRIS player on the private session bus with four tracks (two with generated covers, one with long names, one with no cover), driven through its own methods (`mp PlayPause`, lib.sh); up only for the states that want it |
| weather | a stub `curl` on PATH that answers every request with one fixed Open-Meteo reading, so nothing reaches the network; a place is stored with the shell's own `weather set` ipc for the card states and cleared after |
| phone satellite, phone panel, Nearby over KDE Connect | the real `phone-bridge` (on PATH, built from this repo) reading `pkgs/phone-bridge/tests/mock-kdeconnectd.py` on the private session bus, driven through its `org.mock.Control` `Apply` method; a stub `cliphist` lists three fixed clips |
| pointer | `vpointer.c`, a persistent `zwlr_virtual_pointer` (headless sway has no pointer; without one there is no hover or click) |

The shell runs from a copy of the config with two patches, both checked by `run.sh` (it fails
loudly if one stops applying, so update it when the code moves): `Commons/Monitors.qml`
`isFocused` returns true (sway has no Hyprland focus), and `oledShiftInterval` is made huge (the
OLED orbit would move the pill one pixel every three minutes).

## What is not covered, and why

- **Populated Wi-Fi and Bluetooth lists, battery, power profiles, network state.** The system bus
  is empty on purpose: UPower, NetworkManager, bluez and polkitd answer differently every run.
  The views are captured in their empty ("Wi-Fi is off", "No Bluetooth controller") state.
- **A real polkit request.** The prompt is covered through `authpreview`; the polkit listener
  itself fails to register (allowed in `allowed-log.txt`).
- **Lock screen.** Time and wallpaper dependent. Its picture can be rehearsed on the `lockpreview`
  stage (`preview`, `password`, `busy`, `refuse`, `fault`, `unlock`, `background PREFIX` to stand
  it on a `grim -o OUT PREFIX-OUT.png` capture as the real lock stands on one, and `time HH:mm`
  to show a fixed time, then another to play a change of minute; `time ""` follows the clock
  again); PAM and the session lock are only seen through the real lock.
- **Motion.** One settled frame per state; transitions, springs and handoffs are covered by the
  separate 120 Hz recorder and checker in `motion/` (`motion/README.md`: `record.sh`, `check.mjs`,
  `video.py`, `shader-smoke.sh`).
- **The media card while it plays (its hills and thumb move), clipboard history, emoji and file launcher modes, the file
  picker, hover previews, the Send-with-files and Apple (AirDrop) nearby flows, Recorder busy
  states, Night Light (the tile reads "Unavailable"), Displays with a second output.**
- **Hyprland-specific behaviour** (workspaces content, per-monitor focus): sway stands in.
- **Dictation clock** is not masked: it is captured one second after the mic comes up and the
  stability check retries across a second boundary.

## Determinism, and the noise that is neutralised

- The **clock** in the island is masked (`masks.txt`, logical px, scaled for the scenario). The
  **calendar** shows today's date, so `compare.sh` skips it (with a note) when the two runs were
  made on different days (`date-dependent.txt`).
- Live sysfs/procfs values are replaced: backlight and keyboard backlight (bind-mounted fakes),
  `/proc/stat` and `/proc/meminfo` (fixed, so the CPU/memory gauges are constant), the charge
  limit file (`QUICKSHELL_CHARGE_TYPES`). `brightnessctl` and `hyprctl` are stubs, so nothing the
  shell runs can reach the real machine.
- Installed applications, wallpapers and the theme's compositor background are fixtures
  (`XDG_DATA_DIRS` points at a scratch dir; the wallpaper pickers list generated gradients).
- Animations that never rest are masked per capture in `masks.txt`: the radar rings, the
  password caret, the checking spinner, the dictation spinner, the "Connecting…" dots.
- Every capture is two frames a fraction of a second apart that must be identical (after the
  masks); a state that does not settle is retried from a clean reset up to five times, then
  reported and the run fails. Transient states (OSD, moments) are captured within their dwell.
- Text that draws the harness's own path (the calendar's "no calendar addresses in
  /tmp/qs-verify-<user>/...") ties captures to `QS_VERIFY_WORK`; use the default for a baseline
  you want to compare against.
- Not available: libfaketime (it hangs quickshell at startup), so the wall clock is real.
- Only the log at *load* is checked. Warnings that appear while states are driven stay in
  `$QS_VERIFY_WORK/quickshell.log` (at the commit the baseline was taken: `AuthPrompt.qml` TypeErrors
  when the preview is hidden, and Qt text-input/keyboard-focus notices); `grep WARN` it after a run.
