#!/usr/bin/env bash
# interact.sh OUT_DIR — with the harness running (run.sh), drive the pointer and keys through the
# shared controls and capture what shoot.sh's settled frames cannot show: hover, pressed, a
# click, Space and Enter on a focused control, Left and Right on a segmented control, and the
# tiles and rows: a tile of each kind, a grouped row, and the hairline rows of the phone panel.
#
# One PNG per step (ix-NAME.png), a single frame each: they are for looking at, not for compare.sh.
# Run it on a harness that has not been shot (notification history and mute state carry over).
set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[[ $# -eq 1 ]] || die "usage: interact.sh OUT_DIR"
mkdir -p "$1"
OUT=$(cd "$1" && pwd)
load_env
PH_CALLS=$QSV_WORK/phone-calls.log
PH_STORAGE=$QSV_WORK/phone-storage
NB_SEND=$HOME/send-fixtures

log() { printf '%s\n' "$*" >&2; }
grab() { # NAME [SETTLE]
  sleep "${2:-0.6}"
  grim "$OUT/ix-$1.png"
  log "grab  $1"
}
down() { printf 'down\n' >"$QSV_WORK/vpointer.fifo"; }
up() { printf 'up\n' >"$QSV_WORK/vpointer.fifo"; }
away() { cursor 200 900; }
notify() { env -u LD_LIBRARY_PATH notify-send "$@"; }

# at X Y NAME: hover the control, then press it, then let go off it (no click).
hover_press() {
  cursor "$1" "$2"
  grab "$3-hover"
  down
  grab "$3-pressed" 0.4
  cursor 200 900
  up
  sleep 0.4
}

# seq_keys KEY...: type the keys one after another, 1.4 s apart, in one wtype call: the virtual keyboard
# takes the shell's window focus away when the call ends, so what a key leaves on screen is only
# there while the call runs. Run it in the background and grab between the keys.
seq_keys() {
  local args=(-k Shift_L) k
  for k in "$@"; do
    args+=(-s 1400 -k "$k")
  done
  wtype "${args[@]}" &
}

reset() {
  local k
  for k in launcher control wallpaper profiles calendar nearby recorder theme phone; do
    qsipc "$k" close >/dev/null 2>&1
  done
  qsipc activities dismissMoments >/dev/null 2>&1
  away
  sleep 1.6
}

# ---- a toast's primary pill (Regular) ----
reset
notify -t 6000 -a Mail "New message" "Ada: lunch at noon?"
grab toast-rest 1.3
hover_press 1130 108 toast-dismiss
sleep 7

# ---- a moment's primary pill (Compact) ----
reset
qsipc activities wifi portal "Campus WiFi" >/dev/null
grab moment-rest 1.3
hover_press 1084 40 moment-open
qsipc activities wifi full "" >/dev/null

# ---- the control centre's audio view: Large discs, danger disc, Space and Enter ----
reset
qsipc control toggle >/dev/null
sleep 1.3
keys -k Tab
sleep 0.2
keys -k Return
sleep 1
grab audio-rest 0.8
hover_press 1187 178 audio-mute
hover_press 738 43 audio-back
cursor 1187 178
sleep 0.3
click
grab audio-muted-click 0.8
keys -k space
grab audio-unmuted-space 0.8
keys -k Return
grab audio-muted-return 0.8
keys -k space
away
grab audio-restored 0.8

# ---- the recorder: switch hover and press, compact segmented with a disabled 120 ----
reset
qsipc recorder toggle >/dev/null
grab recorder-rest 1.3
hover_press 1072 204 recorder-switch
cursor 1072 204
sleep 0.3
click
grab recorder-switch-clicked 0.8
keys -k space
away
grab recorder-switch-space 0.8
hover_press 972 240 recorder-fps30
cursor 972 240
sleep 0.3
click
away
grab recorder-fps30-chosen 0.8
# Right moves the keyboard cursor to 60 (ring), Left back to 30, Space chooses what it is on.
seq_keys Right Left Right space
grab recorder-fps-right 0.9
grab recorder-fps-left 1.4
grab recorder-fps-right-again 1.4
grab recorder-fps-space 1.4
cursor 1072 240
grab recorder-fps120-disabled-hover 1.2

# ---- Nearby: the header's segmented controls and the Large primary pill ----
reset
qsipc nearby toggle >/dev/null
grab nearby-rest 1.5
hover_press 1042 47 nearby-send
hover_press 1146 47 nearby-receive
hover_press 923 47 nearby-apple
hover_press 960 104 nearby-choose
# A click on a cell gives the control the keyboard; the keys then walk the cursor over it.
cursor 859 47
sleep 0.3
click
away
seq_keys Left Right Right
grab nearby-left 0.9
grab nearby-right 1.4
grab nearby-right2 1.4

# ---- the control centre's tiles: off, lit, disabled, the badge's own hover, Space ----
reset
qsipc control toggle >/dev/null
sleep 1.3
grab tile-control-rest 0.8
hover_press 958 178 tile-control-peace
cursor 908 178
grab tile-control-peace-badge-hover 0.6
hover_press 1044 107 tile-control-audio-lit
cursor 1128 178
grab tile-control-night-disabled-hover 0.6
cursor 958 178
sleep 0.3
click
away
grab tile-control-peace-clicked 0.8
keys -k space
grab tile-control-peace-space 0.8

# ---- a choice tile (the recorder's capture row): hover and press; the click would start a capture ----
reset
qsipc recorder toggle >/dev/null
grab tile-choice-rest 1.3
hover_press 960 64 tile-choice-window
hover_press 858 64 tile-choice-selected

# ---- a carousel tile: pressed ----
reset
qsipc wallpaper toggle >/dev/null
grab tile-carousel-rest 1.3
hover_press 888 138 tile-carousel

# ---- rows: a grouped row (the audio view's output), pressed ----
reset
qsipc control toggle >/dev/null
sleep 1.3
keys -k Tab
sleep 0.2
keys -k Return
sleep 1
hover_press 960 129 row-grouped-output

# ---- Nearby over KDE Connect: the device tile disabled, then ready, pressed, sending ----
reset
ph_up
qsipc nearby toggle >/dev/null
sleep 1.3
# The earlier steps left Android chosen; KDE Connect is the segment at the far left.
cursor 773 47
sleep 0.3
click
away
grab tile-device-rest 1.5
cursor 960 208
grab tile-device-disabled-hover 0.6
away
nb_kde_stage
grab tile-device-ready 1.0
hover_press 960 361 tile-device
cursor 960 361
sleep 0.3
click
away
ph '{"op":"job_start","job":"up","dev":"s24","direction":"out","files":["IMG_2041.jpg"],"total":18400000}'
sleep 0.4
ph '{"op":"job_update","job":"up","processed":11400000,"percent":62}'
grab tile-device-sending-62 0.9
ph '{"op":"job_end","job":"up"}'
sleep 6
# The send cleared the staged files; stage them again, and send with no reading.
nb_kde_stage
cursor 960 361
sleep 0.3
click
away
ph '{"op":"job_start","job":"up2","dev":"s24","direction":"out","files":["IMG_2041.jpg"]}'
grab tile-device-sending-indeterminate 0.9
ph '{"op":"job_end","job":"up2"}'
sleep 4

# ---- hairline rows (the phone panel): a status row that only reports, a clip row, a notification row
# whose dismiss shows under the pointer ----
reset
qsipc phone toggle >/dev/null
sleep 1.6
grab row-phone-rest 0.6
cursor 1025 108
grab row-status-hover 0.6
hover_press 960 370 row-clip
cursor 960 370
sleep 0.3
click
grab row-clip-copied 0.5
cursor 800 564
grab row-note-hover 0.6
cursor 1172 554
grab row-note-dismiss-hover 0.6
away
