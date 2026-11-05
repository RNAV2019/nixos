#!/usr/bin/env bash
# Scenarios for record.sh. Sourced after lib.sh and load_env (qsipc, keys, cursor, click, ph, ph_up
# are in scope). One function per scenario, named sc_<name> with dashes as underscores; each
# drives the UI and returns, leaving the recorder to cut the log and video. A scenario for a
# feature that a later task adds still drives the UI now. record.sh calls reset_ui between runs.

SCENARIOS="open-close open-twice abc abc-slow retoggle-prepresent retoggle retoggle-fast subview osd-over-open segmented carousel satellite lock-satellite controls subview-keys click-off-early click-through"

wpctl() { command wpctl "$@" 2>/dev/null; }
# MARKS (set by record.sh) collects "toggle NAME epoch_ms" lines, to time the first motion after an ipc.
toggle() {
  [[ -z ${MARKS:-} ]] || printf "toggle %s %s\n" "$1" "$(date +%s%3N)" >>"$MARKS"
  qsipc "$1" toggle >/dev/null
}

# Close everything and park the pointer, as shoot.sh does between states.
reset_ui() {
  local k
  for k in launcher control wallpaper profiles calendar nearby recorder theme phone; do
    qsipc "$k" close >/dev/null 2>&1
  done
  qsipc authpreview hide >/dev/null 2>&1
  qsipc lockpreview preview false >/dev/null 2>&1
  qsipc activities dismissMoments >/dev/null 2>&1
  cursor 200 900
  sleep 1.6
}

# The control centre opens and closes (the control).
sc_open_close() {
  sleep 0.5
  toggle control
  sleep 1.2
  toggle control
  sleep 1.0
}

# The same twice: the first open is cold (nothing warmed it), the second is not.
sc_open_twice() {
  sc_open_close
  sc_open_close
}

# One panel opened over another, 60 ms apart: control, then calendar, then nearby.
sc_abc() {
  sleep 0.5
  toggle control
  sleep 0.06
  toggle calendar
  sleep 0.06
  toggle nearby
  sleep 1.4
  qsipc nearby close >/dev/null 2>&1
  sleep 1.0
}

# The same three panels with time to move between them (a handover from a surface in flight,
# where abc's 60 ms never gets the windows on screen). Each is opened once first so none is cold.
sc_abc_slow() {
  local k
  for k in control calendar nearby; do
    toggle "$k"
    sleep 0.9
    toggle "$k"
    sleep 0.9
  done
  sleep 0.3
  toggle control
  sleep 0.1
  toggle calendar
  sleep 0.1
  toggle nearby
  sleep 1.4
  qsipc nearby close >/dev/null 2>&1
  sleep 1.0
}

# A panel taken before it presents: control, calendar, and nearby 15 ms after calendar, which
# dismisses calendar before its first frame; then control closes and calendar opens afterwards (the
# velocity armed on a taker that never moved must be gone). Windows are warmed first.
sc_retoggle_prepresent() {
  local k
  for k in control calendar nearby; do
    toggle "$k"
    sleep 0.9
    toggle "$k"
    sleep 0.9
  done
  sleep 0.3
  toggle control
  sleep 0.12
  toggle calendar
  sleep 0.015
  toggle nearby
  sleep 1.0
  qsipc nearby close >/dev/null 2>&1
  sleep 0.9
  toggle calendar
  sleep 1.2
  qsipc calendar close >/dev/null 2>&1
  sleep 1.0
}

# The control centre toggled three times, 80 ms apart (open, close, open).
sc_retoggle() {
  sleep 0.5
  toggle control
  sleep 0.08
  toggle control
  sleep 0.08
  toggle control
  sleep 1.4
  qsipc control close >/dev/null 2>&1
  sleep 1.0
}

# Control centre into its Wi-Fi view and back.
sc_subview() {
  sleep 0.5
  toggle control
  sleep 1.3
  keys -k Return
  sleep 1.2
  keys -k Escape
  sleep 1.2
  qsipc control close >/dev/null 2>&1
  sleep 1.0
}

# The volume OSD arriving while the control centre is open, and again as it closes.
sc_osd_over_open() {
  sleep 0.5
  toggle control
  sleep 1.3
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
  sleep 0.4
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.65
  sleep 0.5
  qsipc control close >/dev/null 2>&1
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.45
  sleep 2.0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
}

# The recorder's segmented control (frame rate), moved by its F key.
sc_segmented() {
  sleep 0.5
  toggle recorder
  sleep 1.4
  keys -k f
  sleep 0.5
  keys -k f
  sleep 0.5
  keys -k f
  sleep 0.8
  qsipc recorder close >/dev/null 2>&1
  sleep 1.0
}

# The theme picker's carousel, arrowed right and back.
sc_carousel() {
  sleep 0.5
  toggle theme
  sleep 1.5
  keys -k Right
  sleep 0.5
  keys -k Right
  sleep 0.5
  keys -k Left
  sleep 0.8
  qsipc theme close >/dev/null 2>&1
  sleep 1.0
}

# The phone satellite: docking, the hover card, the volume OSD beside it, the phone panel.
sc_satellite() {
  ph_up
  sleep 1.0
  cursor 960 26
  sleep 1.2
  cursor 200 900
  sleep 0.8
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
  sleep 0.4
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.65
  sleep 2.5
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
  toggle phone
  sleep 1.6
  qsipc phone close >/dev/null 2>&1
  sleep 1.2
}

# The satellite on the lock screen's rehearsal surface.
sc_lock_satellite() {
  ph_up
  sleep 0.5
  qsipc lockpreview preview true >/dev/null
  sleep 1.6
  cursor 960 26
  sleep 1.0
  cursor 200 900
  sleep 0.6
  qsipc lockpreview preview false >/dev/null
  sleep 1.2
}

# Small controls: the recorder's three switches by key (c, a, m), then the control centre's
# Displays view (five Tabs and Return). The workspaces pill is not driven: the harness runs under
# sway, where Quickshell.Hyprland has no workspaces to change.
sc_controls() {
  sleep 0.5
  toggle recorder
  sleep 1.4
  keys -k c
  sleep 0.5
  keys -k a
  sleep 0.5
  keys -k m
  sleep 0.5
  keys -k c
  sleep 0.8
  qsipc recorder close >/dev/null 2>&1
  sleep 1.0
  toggle control
  sleep 1.3
  for _ in 1 2 3 4 5; do
    keys -k Tab
    sleep 0.2
  done
  keys -k Return
  sleep 1.5
  qsipc control close >/dev/null 2>&1
  sleep 1.0
}

# Escape and Backspace through the sliding sub-views (frames land in $OUT/subview-keys-*.png):
# the control centre drilled into Wi-Fi and backed out by Escape 60 ms into the slide, then by
# Escape and by Backspace once settled; the Nearby picker and the phone panel's picker backed out
# by Escape. Each lands on its home view, which the frames show.
sc_subview_keys() {
  local shot="$OUT/subview-keys"
  sleep 0.5
  toggle control
  sleep 1.3
  keys -k Return
  sleep 0.06
  keys -k Escape
  sleep 1.4
  grim "$shot-ctl-mid-escape.png"
  keys -k Return
  sleep 1.4
  keys -k Escape
  sleep 1.4
  grim "$shot-ctl-escape.png"
  keys -k Return
  sleep 1.4
  keys -k BackSpace
  sleep 1.4
  grim "$shot-ctl-backspace.png"
  qsipc control close >/dev/null 2>&1
  sleep 1.0
  toggle nearby
  sleep 1.4
  keys -k Return
  sleep 1.4
  grim "$shot-nearby-picker.png"
  keys -k Escape
  sleep 1.4
  grim "$shot-nearby-home.png"
  qsipc nearby close >/dev/null 2>&1
  sleep 1.0
  ph_up
  toggle phone
  sleep 1.6
  keys -k Right
  sleep 0.3
  keys -k Return
  sleep 1.6
  grim "$shot-phone-picker.png"
  keys -k Escape
  sleep 1.4
  grim "$shot-phone-home.png"
  qsipc phone close >/dev/null 2>&1
  sleep 1.0
}

# The control centre toggled five times, 30 ms apart, so each turn lands inside the last one's
# fade (run after another scenario: a cold window swallows the toggles before its first frame).
sc_retoggle_fast() {
  sleep 0.5
  toggle control
  sleep 0.03
  toggle control
  sleep 0.03
  toggle control
  sleep 0.03
  toggle control
  sleep 0.03
  toggle control
  sleep 1.4
  qsipc control close >/dev/null 2>&1
  sleep 1.0
}

# A click off the card while it is still opening dismisses it, as it does at rest: the input
# region is the final card shape from the first frame. The pointer is set first, so the click is
# the only thing that happens 200 ms into the open. Check: surface.control.h ends back at the pill.
sc_click_off_early() {
  sleep 0.5
  # Once first, so the window is not cold and the click lands mid-morph.
  toggle control
  sleep 1.2
  qsipc control close >/dev/null 2>&1
  sleep 1.0
  cursor 200 900
  sleep 0.3
  toggle control
  sleep 0.2
  click
  sleep 1.4
  # Control: the same click at rest dismisses too.
  toggle control
  sleep 1.2
  click
  sleep 1.2
}

# A transient with cardInput false (the volume flash) passes clicks through to the island under
# it: the click on the pill pins it open (surface-less, so look for island.* motion lines).
sc_click_through() {
  sleep 0.5
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
  sleep 0.5
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.60
  sleep 0.4
  cursor 960 18
  sleep 0.2
  click
  sleep 1.2
  cursor 200 900
  sleep 1.0
}
