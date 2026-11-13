#!/usr/bin/env bash
# shoot.sh OUT_DIR — with the harness running (run.sh), capture one PNG per surface and state.
#
# Each state is a `shot NAME SETTLE GAP SETUP [TEARDOWN]`: reset the UI, run SETUP, wait SETTLE
# seconds for the animations, grab two frames GAP seconds apart and keep the second only if the
# two are identical (clock and other masked regions painted over first); otherwise reset and try
# again. A state that never settles is reported and the run exits non-zero.
set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[[ $# -eq 1 ]] || die "usage: shoot.sh OUT_DIR"
mkdir -p "$1"
OUT=$(cd "$1" && pwd)
load_env
PH_CALLS=$QSV_WORK/phone-calls.log
PH_STORAGE=$QSV_WORK/phone-storage
NB_SEND=$HOME/send-fixtures
TMP=$(mktemp -d "$QSV_WORK/shoot.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
RT=$XDG_RUNTIME_DIR
FAILED=()
ONLY=${QS_SHOOT_ONLY:-}
# A harness whose orbit is on the move (run.sh QS_OLED_INTERVAL_MS) shoots the orbit check and nothing
# else; a default one has no orbit to check.
if [[ -n ${QSV_OLED_INTERVAL:-} ]]; then
  [[ -z $ONLY || $ONLY == check:oled-orbit ]] || die "this harness has a moving orbit; it only shoots check:oled-orbit"
  ONLY=check:oled-orbit
elif [[ $ONLY == check:oled-orbit ]]; then
  die "check:oled-orbit needs a harness started with QS_OLED_INTERVAL_MS"
fi

if [[ -z $ONLY ]]; then
  [[ -e $QSV_WORK/shot.done ]] && die "this harness has already been shot (notification history, backlight and other state carry over); stop.sh, then run.sh again"
  : >"$QSV_WORK/shot.done"
fi

[[ -n $ONLY ]] || rm -f "$OUT"/*.png
[[ -n $ONLY ]] || rm -rf "$OUT/diff" "$OUT/unstable"

# ---- the machinery ----

log() { printf '%s\n' "$*" >&2; }
wpctl() { command wpctl "$@" 2>/dev/null; }

reset_ui() {
  local k
  for k in launcher control wallpaper profiles calendar nearby recorder theme phone media; do
    qsipc "$k" close >/dev/null 2>&1
  done
  qsipc authpreview hide >/dev/null 2>&1
  qsipc keys close >/dev/null 2>&1
  qsipc activities dismissMoments >/dev/null 2>&1
  cursor 200 900
  sleep 1.6
}

same_frames() { # NAME A B
  local ma=$TMP/ma.png mb=$TMP/mb.png diff
  masked "$1" "$QSV_SCALE" "$2" "$ma"
  masked "$1" "$QSV_SCALE" "$3" "$mb"
  diff=$(magick compare -metric AE "$ma" "$mb" null: 2>&1)
  [[ ${diff%% *} == 0 ]]
}

shot() { # NAME SETTLE GAP SETUP [TEARDOWN]
  local name=$1 settle=$2 gap=$3 setup=$4 teardown=${5:-:} attempt
  [[ -n $ONLY && $name != "$ONLY" ]] && return 0
  for attempt in 1 2 3 4 5; do
    reset_ui
    $setup
    sleep "$settle"
    grim "$TMP/a.png"
    sleep "$gap"
    grim "$TMP/b.png"
    $teardown
    if same_frames "$name" "$TMP/a.png" "$TMP/b.png"; then
      cp "$TMP/b.png" "$OUT/$name.png"
      log "ok    $name (attempt $attempt)"
      return 0
    fi
    log "retry $name (attempt $attempt not settled)"
  done
  FAILED+=("$name")
  mkdir -p "$OUT/unstable"
  cp "$TMP/a.png" "$OUT/unstable/$name.a.png"
  cp "$TMP/b.png" "$OUT/unstable/$name.b.png"
  log "FAIL  $name never settled"
}

# ---- panels ----

open_panel() { qsipc "$1" toggle >/dev/null; }
close_panel() { qsipc "$1" close >/dev/null 2>&1; }

setup_launcher() { open_panel launcher; }
setup_launcher_query() {
  open_panel launcher
  sleep 1.2
  type_text "te"
}
setup_launcher_calc() {
  open_panel launcher
  sleep 1.2
  type_text "12*(3+4)"
}

control_view() { # TABS: open the control centre and enter the tile TABS Tabs along
  open_panel control
  sleep 1.3
  local i
  for ((i = 0; i < $1; i++)); do
    keys -k Tab
    sleep 0.2
  done
  keys -k Return
}
setup_control() { open_panel control; }
setup_control_wifi() { control_view 0; }
setup_control_audio() { control_view 1; }
setup_control_bluetooth() { control_view 2; }
setup_control_displays() { control_view 5; }
setup_control_focus() { # keyboard focus ring on the Night Light tile
  open_panel control
  sleep 1.3
  keys -k Tab -k Tab -k Tab -k Tab
}

setup_calendar() { open_panel calendar; }
setup_nearby() { open_panel nearby; }
setup_session() { open_panel session; }
teardown_session() { open_panel session; }
setup_profiles() { open_panel profiles; }
setup_theme() { open_panel theme; }
setup_wallpaper() { open_panel wallpaper; }
setup_recorder() { open_panel recorder; }
# The cheatsheet, as Hyprland asks for it while AltGr is held, alone and over an open panel.
setup_keys() { qsipc keys open >/dev/null; }
setup_keys_over_panel() {
  open_panel control
  sleep 1.2
  qsipc keys open >/dev/null
}
# The picker starts a screen capture on Return; the stub `wl-screenrec` fails, and the pill says so.
# It takes no pointer and dwells 8 s, so the next state waits it out.
setup_recorder_failed() {
  open_panel recorder
  sleep 1.3
  keys -k Return
}
teardown_recorder_failed() { sleep 9; }

# ---- the island at rest ----

setup_none() { :; }
setup_hover_island() { cursor 960 26; }
setup_hover_workspaces() { cursor 85 26; }

# ---- the auth prompt, through the preview stage's own ipc ----

setup_auth_pkexec() { qsipc authpreview ask pkexec >/dev/null; }
setup_auth_plain() { qsipc authpreview ask plain >/dev/null; }
setup_auth_long() { qsipc authpreview ask long >/dev/null; }
setup_auth_identities() { qsipc authpreview ask identities >/dev/null; }
setup_auth_typing() {
  qsipc authpreview ask pkexec >/dev/null
  sleep 1.3
  type_text "hunter2"
}
setup_auth_checking() {
  qsipc authpreview ask pkexec >/dev/null
  sleep 1.3
  type_text "hunter2"
  qsipc authpreview checking >/dev/null
}
setup_auth_failed() {
  qsipc authpreview ask pkexec >/dev/null
  sleep 1.3
  qsipc authpreview checking >/dev/null
  qsipc authpreview fail "Authentication failed" >/dev/null
}

# ---- OSDs: the fake sysfs files, and wpctl against the private PipeWire ----

quiet_wait() { sleep 2.4; }
setup_osd_brightness() {
  echo 480 >"$QSV_WORK/fake/backlight/panel/brightness"
  quiet_wait
  echo 720 >"$QSV_WORK/fake/backlight/panel/brightness"
}
setup_osd_kbd() {
  echo 1 >"$QSV_WORK/fake/leds/test::kbd_backlight/brightness"
  quiet_wait
  echo 2 >"$QSV_WORK/fake/leds/test::kbd_backlight/brightness"
}
setup_osd_volume() {
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
  quiet_wait
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.65
}
setup_osd_volume_muted() {
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.65
  quiet_wait
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
}
teardown_osd_volume() {
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
}
setup_osd_mic_muted() {
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
  quiet_wait
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1
}
setup_osd_mic_on() {
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1
  quiet_wait
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
}
teardown_osd_mic() { wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0; }

# ---- rebuild pill: nix's internal-json log, appended to the file the shell tails ----

RB_LOG=$RT/rebuild.jsonl
RB_DEAD_PID=3999999 # no such process: a run with nothing alive ends after its quiet period
rb_pid=
rb_id() { echo $((rb_pid * 4294967296 + $1)); }
rb_emit() { printf '%s\n' "$1" >>"$RB_LOG"; }
rb_open() { # tail -F finds a new file within a second; the first event must not wait for it
  : >"$RB_LOG"
  sleep 1.3
}
rb_spawn() { # a live process the run's ids can name, so the run does not end by itself
  setsid sleep 600 >/dev/null 2>&1 &
  rb_pid=$!
}
rb_eval() { rb_emit "{\"action\":\"start\",\"id\":$(rb_id 1),\"level\":3,\"type\":0,\"text\":\"evaluating\",\"fields\":[]}"; }
rb_announce() { # N: "these N derivations will be built", then the builds activity
  rb_emit "{\"action\":\"msg\",\"level\":3,\"msg\":\"these $1 derivations will be built:\"}"
  rb_emit "{\"action\":\"start\",\"id\":$(rb_id 2),\"level\":3,\"type\":104,\"text\":\"\",\"fields\":[]}"
}
rb_announce_fetch() { # N: "these N paths will be fetched", then the copy-paths activity
  rb_emit "{\"action\":\"msg\",\"level\":3,\"msg\":\"these $1 paths will be fetched (12.0 MiB download, 48.0 MiB unpacked):\"}"
  rb_emit "{\"action\":\"start\",\"id\":$(rb_id 3),\"level\":3,\"type\":103,\"text\":\"\",\"fields\":[]}"
}
rb_progress() { # DONE TOTAL RUNNING FAILED
  rb_emit "{\"action\":\"result\",\"id\":$(rb_id 2),\"type\":105,\"fields\":[$1,$2,$3,$4]}"
}
rb_fetch_progress() { # DONE TOTAL RUNNING FAILED
  rb_emit "{\"action\":\"result\",\"id\":$(rb_id 3),\"type\":105,\"fields\":[$1,$2,$3,$4]}"
}
rb_build() { # a derivation building: the pill says "Building" while one is open
  rb_emit "{\"action\":\"start\",\"id\":$(rb_id 4),\"level\":3,\"type\":105,\"text\":\"building '/nix/store/x-demo.drv'\",\"fields\":[\"/nix/store/x-demo.drv\",\"\",1,1]}"
}
rb_finish() { # leave the run to end: kill the live process, wait out the quiet period and dwell
  [[ -n $rb_pid ]] && kill "$rb_pid" 2>/dev/null
  rb_pid=
  # The pill takes no pointer, so a failure is waited out (quiet period, then its 8 s dwell).
  sleep 13
}
setup_rebuild_building_unknown() { # evaluating, nothing built yet
  rb_open
  rb_spawn
  rb_eval
}
setup_rebuild_building() {
  rb_open
  rb_spawn
  rb_eval
  rb_announce 12
  rb_build
  rb_progress 5 12 1 0
}
setup_rebuild_building_mixed() { # 4 built + 8 fetched, 2 and 4 of them done: 6 of 12
  rb_open
  rb_spawn
  rb_eval
  rb_announce 4
  rb_announce_fetch 8
  rb_build
  rb_progress 2 4 1 0
  rb_fetch_progress 4 8 1 0
}
setup_rebuild_done() {
  rb_open
  rb_pid=$RB_DEAD_PID
  rb_eval
  rb_announce 12
  rb_progress 6 12 1 0
  sleep 3.3
  rb_progress 12 12 0 0
  rb_emit "{\"action\":\"stop\",\"id\":$(rb_id 2)}"
  rb_emit "{\"action\":\"stop\",\"id\":$(rb_id 1)}"
  rb_pid=
  sleep 3.7 # the quiet period, then "Switched", captured inside its 2.5 s dwell
}
setup_rebuild_failed() {
  rb_open
  rb_spawn
  rb_eval
  rb_announce 12
  rb_build
  rb_progress 7 12 1 1
  rb_emit "{\"action\":\"msg\",\"level\":0,\"msg\":\"error: builder for '/nix/store/x-demo.drv' failed with exit code 1\"}"
  [[ -n $rb_pid ]] && kill "$rb_pid"
  rb_pid=
  sleep 4.4
}
teardown_rebuild() { rb_finish; }

# ---- dictation pill: Handy's overlay events on the fake socket ----

DICT=$QSV_WORK/dictation.events
dict() { printf '%s\n' "$1" >>"$DICT"; }
dict_levels() { # send the same 16 buckets 40 times so the smoothing converges
  local i
  for i in $(seq 40); do
    dict '{"event":"levels","levels":[0.9,0.8,0.7,0.6,0.5,0.45,0.4,0.35,0.3,0.25,0.2,0.15,0.1,0.08,0.05,0.02]}'
  done
}
setup_dictation_listening() { dict '{"event":"state","state":"recording"}'; }
setup_dictation_ready() {
  dict '{"event":"state","state":"recording"}'
  sleep 1.2
  dict '{"event":"ready"}'
  dict_levels
}
setup_dictation_live() {
  dict '{"event":"state","state":"streaming"}'
  sleep 1.2
  dict '{"event":"ready"}'
  dict_levels
  dict '{"event":"text","committed":"Dictation shows the words as they come","tentative":" and the ones still being rewritten"}'
}
setup_dictation_working() {
  dict '{"event":"state","state":"recording"}'
  sleep 1.2
  dict '{"event":"state","state":"transcribing"}'
}
setup_dictation_polishing() {
  dict '{"event":"state","state":"recording"}'
  sleep 1.2
  dict '{"event":"state","state":"processing"}'
}
teardown_dictation() { dict '{"event":"hide"}'; }

# ---- nearby: the stub `nearby` replays nearby.events ----

NB=$QSV_WORK/nearby.events
nb() { printf '%s\n' "$1" >>"$NB"; }
nb_status() { # JSON status body fields override the baseline's
  nb "{\"event\":\"status\",\"status\":{\"mode\":\"android\",\"visible\":$1,\"remaining\":null,\"scanning\":$2,\"busy\":false,\"name\":\"test-laptop\",\"download_dir\":\"/tmp/Downloads\",\"android\":{\"running\":true,\"port\":47713,\"error\":null},\"apple\":{\"available\":true,\"receiving\":false,\"visible\":null,\"reason\":null,\"error\":null}}}"
}
nb_transfer() { # STATE BYTES [saved path]
  local saved="[]"
  [[ -n ${3:-} ]] && saved="[\"$3\"]"
  nb "{\"event\":\"transfer\",\"transfer\":{\"id\":\"qs:192.168.1.20:41234\",\"protocol\":\"quickshare\",\"direction\":\"in\",\"state\":\"$1\",\"peer\":\"Galaxy S24\",\"pin\":\"4821\",\"kind\":\"files\",\"files\":[\"IMG_0001.jpg\"],\"text\":null,\"saved_paths\":$saved,\"total_bytes\":2400000,\"bytes\":$2,\"error\":null,\"started\":$(date +%s)}}"
}
nb_peers() {
  nb '{"event":"peer","peer":{"id":"qs:AAAA","name":"Galaxy S24","protocol":"quickshare","kind":"phone","via":"lan","rssi":null}}'
  nb '{"event":"peer","peer":{"id":"qs:BBBB","name":"Pixel Tablet","protocol":"quickshare","kind":"tablet","via":"lan","rssi":null}}'
  nb '{"event":"peer","peer":{"id":"qs:CCCC","name":"Work Laptop","protocol":"quickshare","kind":"laptop","via":"lan","rssi":null}}'
}
nb_reset() {
  nb '{"event":"peer_lost","id":"qs:AAAA"}'
  nb '{"event":"peer_lost","id":"qs:BBBB"}'
  nb '{"event":"peer_lost","id":"qs:CCCC"}'
  nb_transfer cancelled 0
  nb '{"event":"transfers_cleared"}'
  nb_status false false
}
setup_nearby_peers() {
  nb_status false true
  nb_peers
  open_panel nearby
}
setup_nearby_receive() {
  nb_status true false
  open_panel nearby
  sleep 1.3
  qsipc nearby receive >/dev/null
}
setup_nearby_arrivals() {
  nb_transfer finished 2400000 /tmp/Downloads/IMG_0001.jpg
  nb_status true false
  open_panel nearby
  sleep 1.3
  qsipc nearby receive >/dev/null
}
setup_sharing_connecting() { nb_transfer connecting 0; }
setup_sharing_offer() { nb_transfer waiting_consent 0; }
setup_sharing_receiving() { nb_transfer in_progress 1200000; }
setup_sharing_saved() {
  nb_transfer in_progress 2399999
  sleep 1.0
  nb_transfer finished 2400000 /tmp/Downloads/IMG_0001.jpg
}
teardown_nearby() { nb_reset; }

# ---- moments ----

setup_moment_plugged() { qsipc activities plug 78 80 >/dev/null; }
setup_moment_wifi() { qsipc activities wifi portal "Campus WiFi" >/dev/null; }
teardown_wifi() { qsipc activities wifi full "" >/dev/null; }

# ---- what is playing: the mock player (lib.sh media_up), and weather from the stub curl ----

setup_card() { cursor 960 26; }
setup_media() { open_panel media; }
# The panel grown out of the open card by a click on what is playing and closed by Escape with
# the pointer left there: back in the hover card, which it leaves standing open.
setup_card_returned() {
  cursor 960 26
  sleep 0.6
  cursor 790 52
  sleep 0.6
  click
  sleep 1.2
  keys -k Escape
}
# Paused at a place of its own choosing, so the scrub bar reads the same every run.
media_pause() {
  mp Pause
  mp SetPosition ox /org/qsv/track/0 96000000
  sleep 0.8
}

# ---- notifications ----

NOTIFY_TTL=4000
notify() { env -u LD_LIBRARY_PATH notify-send -t "$NOTIFY_TTL" "$@"; }
# A toast leaves by its own timeout: closing it over dbus leaves it in the popup queue.
wait_toast_gone() { sleep $((NOTIFY_TTL / 1000 + 1)); }
setup_notify_basic() { notify -a Mail "New message" "Ada: lunch at noon?"; }
setup_notify_critical() { notify -a System -u critical "Battery critically low" "Plug in the charger now."; }
setup_notify_long() {
  notify -a Calendar "Quarterly planning review moved to the large meeting room on the fourth floor" "The agenda has changed: please read the attached notes before the meeting starts, and bring the numbers for the second quarter. Coffee will be provided by the office team."
}
# Run first among the notification states: the list holds what has been sent, so a state shot
# after others would show their entries, aged by however long the run has taken.
setup_control_notifications() {
  NOTIFY_TTL=1000 notify -a Mail "Earlier message" "Seen already"
  sleep 1.8
  open_panel control
}

# A check the screenshots cannot make: PASS or FAIL in the log, and FAIL fails the run.
check() { # NAME COMMAND...
  local name=$1
  shift
  [[ -n $ONLY && $ONLY != "check:$name" ]] && return 0
  if "$@"; then
    log "check $name"
  else
    FAILED+=("check:$name")
    log "FAIL  check $name"
  fi
}

# ---- the burn-in orbit ----
#
# Only meaningful on a harness started with QS_OLED_INTERVAL_MS (run.sh): the orbit steps every
# few hundred ms there, so no state could be compared, and that is all such a harness shoots.

# Where a pill is in a capture, "X Y W H": the part of a strip of the top edge (columns X0 to X1)
# that differs from the compositor's own background, which is the same size as the output.
strip_box() { # CAPTURE X0 X1
  local w=$(($3 - $2)) box
  box=$(magick "$1" -crop "${w}x80+$2+0" +repage \
    \( "$QSV_WORK/bg.png" -crop "${w}x80+$2+0" +repage \) \
    -compose difference -composite -colorspace gray -threshold 10% -format '%@' info:)
  [[ $box =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]] || {
    echo "none"
    return
  }
  echo "$((BASH_REMATCH[3] + $2)) ${BASH_REMATCH[4]} ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
}
island_box() { strip_box "$1" 560 1360; }
workspaces_box() { strip_box "$1" 0 400; }

# The pill is on the move: two captures a second apart find it in two places.
oled_orbit_moves() {
  local a=$TMP/orbit-a.png b=$TMP/orbit-b.png ia ib wa wb
  sleep 2
  grim "$a"
  sleep 1
  grim "$b"
  ia=$(island_box "$a")
  ib=$(island_box "$b")
  wa=$(workspaces_box "$a")
  wb=$(workspaces_box "$b")
  log "      island     $ia -> $ib"
  log "      workspaces $wa -> $wb"
  [[ $ia != none && $wa != none && $ia != "$ib" && $wa != "$wb" ]]
}

setup_phone_satellite() { :; }
setup_phone_satellite_card() { cursor 960 26; }
setup_phone_satellite_hover() { cursor 1045 26; }
setup_phone_satellite_low() { ph '{"op":"battery","dev":"s24","charge":14,"charging":false}'; }
teardown_phone_low() { ph '{"op":"battery","dev":"s24","charge":78,"charging":false}'; }
setup_phone_satellite_osd() { setup_osd_volume; }
setup_panel_phone() { open_panel phone; }
setup_panel_phone_hover_tile() {
  open_panel phone
  sleep 1.6
  cursor "$PH_SEND_X" "$PH_ACTIONS_Y"
}
setup_panel_phone_ringing() {
  open_panel phone
  sleep 1.6
  cursor "$PH_RING_X" "$PH_ACTIONS_Y"
  sleep 0.3
  click
}

# Screen positions in the phone panel (opened at 700, 8): the wallpaper disc, and the centres of the
# action tiles (Ring, Send files, Browse; their row sits 154 px down in the card, 90 tall).
PH_DISC_X=776 PH_DISC_Y=222
PH_RING_X=906 PH_SEND_X=1026 PH_BROWSE_X=1146 PH_ACTIONS_Y=207
PH_BROWSE_Y=$PH_ACTIONS_Y
# In the 960 px picker (opened at 480, 8): the Phone and Laptop cells, and the empty state's button.
PK_PHONE_X=1331 PK_LAPTOP_X=1389 PK_SWITCH_Y=36
PK_BROWSE_LAPTOP_X=960 PK_BROWSE_LAPTOP_Y=245

setup_phone_low() { ph '{"op":"battery","dev":"s24","charge":14,"charging":false}'; open_panel phone; }
setup_phone_mobile_off() {
  ph '{"op":"cellular","dev":"s24","type":"","strength":-1}'
  sleep 1
  open_panel phone
}
# KDE Connect without the phone-state permission: the type comes as "Unknown", the bars still do.
setup_phone_mobile_unknown() {
  ph '{"op":"cellular","dev":"s24","type":"Unknown","strength":4}'
  sleep 1
  open_panel phone
}
# Charging: the longest reading line, "78% · charging", has to fit its tile without an ellipsis.
setup_phone_charging() { ph '{"op":"battery","dev":"s24","charge":78,"charging":true}'; open_panel phone; }
teardown_phone_charging() { ph '{"op":"battery","dev":"s24","charge":78,"charging":false}'; }
teardown_phone_mobile() { ph '{"op":"cellular","dev":"s24","type":"5G","strength":3}'; }
setup_phone_browse_blocked() {
  ph '{"op":"sftp","dev":"s24","grant":false}'
  open_panel phone
  sleep 1.6
  cursor "$PH_BROWSE_X" "$PH_BROWSE_Y"
  sleep 0.3
  click
  sleep 1.2
  cursor 200 900
}
teardown_phone_access() { ph "{\"op\":\"sftp\",\"dev\":\"s24\",\"grant\":true,\"mount\":\"$PH_STORAGE\"}"; }
phone_wallpaper_picker() { # open the panel and the wallpaper chooser, then wait for the phone's listing
  open_panel phone
  sleep 1.6
  cursor "$PH_DISC_X" "$PH_DISC_Y"
  sleep 0.3
  click
  sleep 2.2
  cursor 200 900
}
setup_phone_picker_phone() {
  phone_wallpaper_picker
  type_text "jjjjj"
}
setup_phone_picker_laptop() {
  phone_wallpaper_picker
  cursor "$PK_LAPTOP_X" "$PK_SWITCH_Y"
  sleep 0.3
  click
  sleep 1.5
  cursor 200 900
  type_text "jjjjj"
}
setup_phone_picker_blocked() {
  ph '{"op":"sftp","dev":"s24","grant":false}'
  phone_wallpaper_picker
}
# Choose mountains.jpg from the phone: the file is copied into the state dir and drawn.
setup_phone_wallpaper() {
  phone_wallpaper_picker
  type_text "jjjjj"
  sleep 0.4
  keys -k Return
  sleep 2.5
}
one_wallpaper_copy() {
  local n
  n=$(find "$HOME/.local/state/shell" -maxdepth 1 -name 'phone-wallpaper-*' | wc -l)
  [[ $n -eq 1 ]] && [[ $(cat "$HOME/.local/state/shell/phone-wallpaper") == "$(find "$HOME/.local/state/shell" -maxdepth 1 -name 'phone-wallpaper-*')" ]]
}
# With the phone there KDE Connect is the default; Android, picked on the header, is written down
# and the shell restarted on the same state.
android_pick_kept() {
  open_panel nearby
  sleep 1.5
  cursor 859 47
  sleep 0.3
  click
  sleep 0.6
  cursor 200 900
  close_panel nearby
  sleep 1
  [[ $(cat "$HOME/.local/state/shell/nearby-platform" 2>/dev/null) == android ]] || return 1
  QS_VERIFY_WORK=$QSV_WORK "$QSV_DIR/restart.sh" >/dev/null
}
setup_nearby_android_kept() { open_panel nearby; }
# The control: with nothing kept, the same restart comes back on KDE Connect, so the phone is there.
setup_nearby_kde_after_restart() {
  rm -f "$HOME/.local/state/shell/nearby-platform"
  QS_VERIFY_WORK=$QSV_WORK "$QSV_DIR/restart.sh" >/dev/null
  open_panel nearby
}
browse_opens_nautilus() {
  reset_ui
  : >"$QSV_WORK/launched.log"
  open_panel phone
  sleep 1.6
  cursor "$PH_BROWSE_X" "$PH_BROWSE_Y"
  sleep 0.3
  click
  sleep 2
  grep -qx "nautilus $PH_STORAGE" "$QSV_WORK/launched.log"
}

# The keyboard walks the action tiles (Ring, Send files, Browse): two steps right and Return
# presses Browse.
phone_keys_browse() {
  reset_ui
  : >"$QSV_WORK/launched.log"
  open_panel phone
  sleep 1.6
  keys -k Right
  sleep 0.3
  keys -k Right
  sleep 0.3
  keys -k Return
  sleep 2
  grep -qx "nautilus $PH_STORAGE" "$QSV_WORK/launched.log"
}

# ---- Nearby over KDE Connect (the phone is up, so KDE Connect is the default platform) ----

# The phone's tile, with three files staged (the panel at 700, 8; the tile column's centre).
NB_TILE_X=960 NB_TILE_Y=361
nb_kde_tap() {
  cursor "$NB_TILE_X" "$NB_TILE_Y"
  sleep 0.3
  click
  sleep 0.4
  cursor 200 900
}
setup_nearby_kde_choose() { open_panel nearby; }
setup_nearby_kde_sending() {
  nb_kde_stage
  nb_kde_tap
  ph '{"op":"job_start","job":"up","dev":"s24","direction":"out","files":["IMG_2041.jpg"],"total":18400000}'
  sleep 0.4
  ph '{"op":"job_update","job":"up","processed":11400000,"percent":62}'
}
setup_nearby_kde_sending_quiet() {
  nb_kde_stage
  nb_kde_tap
  ph '{"op":"job_start","job":"up","dev":"s24","direction":"out","files":["IMG_2041.jpg"]}'
}
setup_nearby_kde_sent() {
  nb_kde_stage
  nb_kde_tap
  ph '{"op":"job_start","job":"up","dev":"s24","direction":"out","files":["IMG_2041.jpg"],"total":100}'
  sleep 0.3
  ph '{"op":"job_end","job":"up"}'
}
teardown_nearby_kde_job() { ph '{"op":"job_end","job":"up"}' 2>/dev/null; sleep 4; }
setup_nearby_kde_absent() {
  ph '{"op":"device","id":"s24","reachable":false}'
  sleep 2
  open_panel nearby
  sleep 1.3
  cursor 770 48
  sleep 0.3
  click
  cursor 200 900
}
teardown_nearby_kde_absent() {
  ph '{"op":"device","id":"s24","reachable":true}'
  sleep 3
}
nb_kde_arrivals() {
  ph '{"op":"share_received","dev":"s24","url":"file:///tmp/Downloads/boarding-pass.pdf"}'
  sleep 1.1
  ph '{"op":"share_received","dev":"s24","url":"file:///tmp/Downloads/IMG_2038.jpg"}'
  sleep 1.1
  ph '{"op":"job_start","job":"down","dev":"s24","direction":"in","files":["IMG_2041.jpg"],"total":2400000,"dir":"/tmp/Downloads"}'
  sleep 0.3
  ph '{"op":"job_update","job":"down","processed":1488000,"percent":62}'
}
setup_nearby_kde_receive() {
  nb_kde_arrivals
  open_panel nearby
  sleep 1.3
  qsipc nearby receive >/dev/null
}
setup_sharing_kde_receiving() {
  ph '{"op":"job_start","job":"down","dev":"s24","direction":"in","files":["IMG_2041.jpg"],"total":2400000,"dir":"/tmp/Downloads"}'
  sleep 0.3
  ph '{"op":"job_update","job":"down","processed":1488000,"percent":62}'
}
setup_sharing_kde_saved() {
  ph '{"op":"job_start","job":"down","dev":"s24","direction":"in","files":["IMG_2041.jpg"],"total":2400000,"dir":"/tmp/Downloads"}'
  sleep 0.5
  ph '{"op":"job_update","job":"down","processed":2399999,"percent":99}'
  sleep 0.5
  ph '{"op":"job_end","job":"down"}'
}
teardown_kde_down() { ph '{"op":"job_end","job":"down"}' 2>/dev/null; sleep 5; }

# ---- launcher scopes, the file pickers, a staged send, Displays with two monitors, the lock ----

# The launcher's "Clipboard History" and "Emoji & Symbols" rows, entered by their chips: the entry
# row is the best match for its own word, so Return on it opens the scope. The stub cliphist reads
# its list from a file, which holds five clips for the clipboard state only.
launcher_scope() { # WORD
  open_panel launcher
  sleep 1.2
  type_text "$1"
  sleep 0.6
  keys -k Return
}
setup_launcher_clipboard() {
  cp "$QSV_DIR/fixtures/cliphist.list" "$QSV_WORK/cliphist.list"
  launcher_scope clip
}
teardown_launcher_clipboard() {
  printf '3\thttps://nixos.org/manual/nixos/stable\n2\tmeeting notes for friday\n1\tssh ryan@192.168.1.20\n' >"$QSV_WORK/cliphist.list"
}
setup_launcher_emoji() { launcher_scope emoji; }

# Nearby's picker (Return on "Choose files" in Send) opens on ~/Downloads: the folder first, then
# the files. j moves to the first text file, space marks it and moves on.
setup_picker_files() {
  nb_status false true
  nb_peers
  open_panel nearby
  sleep 1.5
  keys -k Return
  sleep 1.3
  keys -k j -k space
}
# The phone panel's wallpaper chooser, on the laptop side: only folders and pictures are listed,
# so the three text files stay out. It opens in ~/Pictures; h goes up to the home folder with
# Pictures focused, two up is Downloads, and l enters it. (Typing "~" drops now and then.)
setup_picker_images() {
  phone_wallpaper_picker
  cursor "$PK_LAPTOP_X" "$PK_SWITCH_Y"
  sleep 0.3
  click
  sleep 1.5
  cursor 200 900
  keys -k h
  sleep 0.8
  keys -k k -k k
  sleep 0.3
  keys -k l
  sleep 0.8
  keys -k j
}
# Two files sent in with `nearby send`, with a device to send them to.
setup_nearby_send_staged() {
  nb_status false true
  nb_peers
  qsipc nearby send "$HOME/Downloads/sunset.png" >/dev/null
  sleep 0.8
  qsipc nearby send "$HOME/Downloads/notes.txt" >/dev/null
}

# Displays with a laptop panel and an external monitor (mock-hyprland.sh; the shell restarts into
# it, so it comes after every state that must not see Hyprland).
setup_control_displays_two() { control_view 5; }

# The lock on the rehearsal stage, standing on a fixed capture (the compositor's own background)
# with the clock held at 09:41; the way in plays out in the settle time.
LOCK_BG=$QSV_WORK/lockbg
lock_stage() {
  cp "$QSV_WORK/bg.png" "$LOCK_BG-HEADLESS-1.png"
  mkdir -p "$HOME/.local/share/wallpaper"
  ln -sf "$QSV_WORK/bg.png" "$HOME/.local/share/wallpaper/current"
  qsipc lockpreview background "$LOCK_BG" >/dev/null
  qsipc lockpreview time 09:41 >/dev/null
}
setup_lock_preview() {
  lock_stage
  qsipc lockpreview preview true >/dev/null
}
setup_lock_preview_password() {
  setup_lock_preview
  sleep 2.5
  qsipc lockpreview password hunter2 >/dev/null
}
setup_lock_preview_refuse() {
  setup_lock_preview
  sleep 2.5
  qsipc lockpreview password hunter2 >/dev/null
  sleep 0.5
  qsipc lockpreview busy true >/dev/null
  sleep 0.5
  qsipc lockpreview refuse >/dev/null
}
# The way out as the real unlock plays it; the stage comes down when it ends.
teardown_lock() {
  qsipc lockpreview unlock >/dev/null
  sleep 2.5
  qsipc lockpreview preview false >/dev/null
  sleep 0.5
}

# ---- the run ----

{
  echo "scale=$QSV_SCALE"
  echo "theme=$QSV_THEME"
  echo "date=$(date +%F)"
  echo "source=$QSV_SRC"
  echo "commit=$(git -C "$QSV_SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} >"$OUT/meta.txt"

[[ -z ${QSV_OLED_INTERVAL:-} ]] || check oled-orbit oled_orbit_moves

shot rest 1.0 0.3 setup_none
shot hover-island 1.2 0.3 setup_hover_island
shot hover-workspaces 1.2 0.3 setup_hover_workspaces

shot panel-launcher 1.5 0.3 setup_launcher
shot panel-launcher-query 1.0 0.3 setup_launcher_query
shot panel-launcher-calc 1.0 0.3 setup_launcher_calc
shot panel-control 1.5 0.3 setup_control
shot panel-control-focus 1.0 0.3 setup_control_focus
shot panel-control-wifi 1.8 0.3 setup_control_wifi
shot panel-control-audio 1.8 0.3 setup_control_audio
shot panel-control-bluetooth 1.8 0.3 setup_control_bluetooth
shot panel-control-displays 1.8 0.3 setup_control_displays
shot panel-calendar 1.5 0.3 setup_calendar
shot panel-nearby 1.5 0.3 setup_nearby
shot panel-nearby-peers 1.5 0.3 setup_nearby_peers teardown_nearby
shot panel-nearby-receive 1.8 0.3 setup_nearby_receive teardown_nearby
shot panel-nearby-arrivals 1.8 0.3 setup_nearby_arrivals teardown_nearby
shot panel-session 1.5 0.3 setup_session teardown_session
shot panel-profiles 1.5 0.3 setup_profiles
shot panel-theme 1.5 0.3 setup_theme
shot panel-wallpaper 1.5 0.3 setup_wallpaper
shot panel-recorder 1.5 0.3 setup_recorder
shot keys 1.2 0.3 setup_keys
shot keys-over-panel 1.2 0.3 setup_keys_over_panel

shot auth-pkexec 1.5 0.3 setup_auth_pkexec
shot auth-plain 1.5 0.3 setup_auth_plain
shot auth-long 1.5 0.3 setup_auth_long
shot auth-identities 1.5 0.3 setup_auth_identities
shot auth-typing 1.0 0.3 setup_auth_typing
shot auth-checking 1.0 0.3 setup_auth_checking
shot auth-failed 1.2 0.3 setup_auth_failed

shot osd-brightness 0.7 0 setup_osd_brightness
shot osd-keyboard-backlight 0.7 0 setup_osd_kbd
shot osd-volume 0.7 0 setup_osd_volume teardown_osd_volume
shot osd-volume-muted 0.7 0 setup_osd_volume_muted teardown_osd_volume
shot osd-mic-muted 0.7 0 setup_osd_mic_muted teardown_osd_mic
shot osd-mic-on 0.7 0 setup_osd_mic_on teardown_osd_mic

shot rebuild-building-unknown 1.2 0.3 setup_rebuild_building_unknown teardown_rebuild
shot rebuild-building 1.2 0.3 setup_rebuild_building teardown_rebuild
shot rebuild-building-mixed 1.2 0.3 setup_rebuild_building_mixed teardown_rebuild
shot rebuild-done 0.6 0.3 setup_rebuild_done teardown_rebuild
shot rebuild-failed 0.8 0.3 setup_rebuild_failed teardown_rebuild
shot recorder-failed 2.0 0.3 setup_recorder_failed teardown_recorder_failed

shot dictation-listening 1.2 0.3 setup_dictation_listening teardown_dictation
shot dictation-ready 1.3 0.1 setup_dictation_ready teardown_dictation
shot dictation-live 1.3 0.1 setup_dictation_live teardown_dictation
shot dictation-transcribing 1.2 0.3 setup_dictation_working teardown_dictation
shot dictation-polishing 1.2 0.3 setup_dictation_polishing teardown_dictation

shot sharing-connecting 1.3 0.3 setup_sharing_connecting teardown_nearby
shot sharing-offer 1.3 0.3 setup_sharing_offer teardown_nearby
shot sharing-receiving 1.3 0.3 setup_sharing_receiving teardown_nearby
shot sharing-saved 1.0 0.3 setup_sharing_saved teardown_nearby

shot moment-plugged 1.2 0.1 setup_moment_plugged
shot moment-wifi-signin 1.3 0.3 setup_moment_wifi teardown_wifi

shot panel-control-notifications 1.5 0.3 setup_control_notifications
shot notify-basic 1.3 0.3 setup_notify_basic wait_toast_gone
shot notify-critical 1.3 0.3 setup_notify_critical wait_toast_gone
shot notify-long 1.3 0.3 setup_notify_long wait_toast_gone

# After everything else: the phone stays connected from here, which the other states must not see.
if [[ -z $ONLY || $ONLY == *phone* || $ONLY == *kde* ]]; then
  ph_up
  shot phone-satellite 1.0 0.3 setup_phone_satellite
  shot phone-satellite-card 1.4 0.3 setup_phone_satellite_card
  shot phone-satellite-hover 1.2 0.3 setup_phone_satellite_hover
  shot phone-satellite-low 1.2 0.3 setup_phone_satellite_low teardown_phone_low
  shot phone-satellite-osd 0.9 0.15 setup_phone_satellite_osd teardown_osd_volume
  shot panel-phone 1.8 0.3 setup_panel_phone
  shot panel-phone-hover-tile 1.0 0.3 setup_panel_phone_hover_tile
  shot panel-phone-ringing 1.0 0.3 setup_panel_phone_ringing
  shot panel-phone-low 1.8 0.3 setup_phone_low teardown_phone_low
  shot panel-phone-charging 1.8 0.3 setup_phone_charging teardown_phone_charging
  shot panel-phone-mobile-off 1.8 0.3 setup_phone_mobile_off teardown_phone_mobile
  shot panel-phone-mobile-unknown 1.8 0.3 setup_phone_mobile_unknown teardown_phone_mobile
  shot panel-phone-browse-blocked 1.8 0.3 setup_phone_browse_blocked teardown_phone_access
  shot panel-phone-picker-phone 1.0 0.3 setup_phone_picker_phone
  shot panel-phone-picker-laptop 1.0 0.3 setup_phone_picker_laptop
  shot panel-phone-picker-blocked 1.0 0.3 setup_phone_picker_blocked teardown_phone_access
  check phone-browse-nautilus browse_opens_nautilus
  check phone-keys-browse phone_keys_browse
  shot panel-nearby-kde-choose 1.5 0.3 setup_nearby_kde_choose
  shot panel-nearby-kde-sending 1.0 0.3 setup_nearby_kde_sending teardown_nearby_kde_job
  shot panel-nearby-kde-sending-quiet 1.0 0.3 setup_nearby_kde_sending_quiet teardown_nearby_kde_job
  shot panel-nearby-kde-sent 0.6 0.2 setup_nearby_kde_sent teardown_nearby_kde_job
  # Before the receive view is asked for: that leaves a request for the next open.
  shot panel-nearby-kde-absent 1.5 0.3 setup_nearby_kde_absent teardown_nearby_kde_absent
  shot sharing-kde-receiving 1.3 0.3 setup_sharing_kde_receiving teardown_kde_down
  shot sharing-kde-saved 1.0 0.3 setup_sharing_kde_saved teardown_kde_down
  shot panel-nearby-kde-receive 1.8 0.3 setup_nearby_kde_receive teardown_kde_down
  # Last: the chosen picture stays on the phone preview from here on.
  shot panel-phone-wallpaper 1.0 0.3 setup_phone_wallpaper
  check phone-one-wallpaper-copy one_wallpaper_copy
  # Last of all, since it restarts the shell: the Android pick outlives it.
  check nearby-android-kept android_pick_kept
  shot panel-nearby-android-kept 1.5 0.3 setup_nearby_android_kept
  shot panel-nearby-kde-after-restart 1.5 0.3 setup_nearby_kde_after_restart
fi

# Last of all, so every state above is taken exactly as it was before these existed (a state
# added in the middle shifts which windows the shell still holds for the ones after it): a
# player with a cover, and a place for the weather, which the stub curl answers for. The phone
# goes first, so no satellite stands beside the pill. The control centre's own state comes after
# the shell's restart above and before the control centre has been shown again: shown once with
# no cover, its media card does not pick up one that arrives later.
if [[ -z $ONLY || $ONLY == card-* || $ONLY == *media* ]]; then
  if busctl --user list 2>/dev/null | grep -q org.mock.Control; then
    ph '{"op":"remove","id":"s24"}'
    sleep 2.5
  fi
  media_up
  qsipc weather set 51.48 0.00 >/dev/null
  sleep 1.5
  shot card-playing 1.4 0.3 setup_card
  shot panel-media 1.5 0.3 setup_media
  media_pause
  shot card-paused 1.4 0.3 setup_card
  shot panel-media-paused 1.5 0.3 setup_media
  shot panel-control-media-paused 1.5 0.3 setup_control
  media_down
  shot card-idle 1.4 0.3 setup_card
  # After every state that was here before it: the card the Now playing panel went back into.
  media_up
  sleep 0.5
  shot card-returned 1.6 0.3 setup_card_returned
  media_down
  qsipc weather clear >/dev/null
  sleep 0.5
fi

# After the states above, which see the shell as it was before these existed: the launcher
# scopes, the pickers and a staged send (the phone comes back for the wallpaper chooser and goes
# again), Displays with two monitors, and the lock last, since a lock scenario leaks into any
# state after it.
if [[ -z $ONLY || $ONLY == launcher-* || $ONLY == picker-* || $ONLY == nearby-send-staged || $ONLY == displays-two || $ONLY == lock-* ]]; then
  fixture_files
  shot launcher-clipboard 1.2 0.3 setup_launcher_clipboard teardown_launcher_clipboard
  shot launcher-emoji 1.2 0.3 setup_launcher_emoji
  shot picker-files 1.2 0.3 setup_picker_files teardown_nearby
  shot nearby-send-staged 1.5 0.3 setup_nearby_send_staged teardown_nearby
  if [[ -z $ONLY || $ONLY == picker-images ]]; then
    ph_up
    shot picker-images 1.0 0.3 setup_picker_images
    ph '{"op":"remove","id":"s24"}'
    sleep 2.5
  fi
  if [[ -z $ONLY || $ONLY == displays-two ]]; then
    hypr_up
    shot displays-two 1.8 0.3 setup_control_displays_two
    hypr_down
  fi
  if [[ -z $ONLY || $ONLY == lock-* ]]; then
    shot lock-preview 1.5 0.3 setup_lock_preview teardown_lock
    shot lock-preview-password 1.5 0.3 setup_lock_preview_password teardown_lock
    shot lock-preview-refuse 0.5 0.1 setup_lock_preview_refuse teardown_lock
    qsipc lockpreview background "" >/dev/null
    qsipc lockpreview time "" >/dev/null
  fi
fi

reset_ui
[[ -n $ONLY || ${#FAILED[@]} -gt 0 ]] || rm -rf "$OUT/unstable"
if [[ ${#FAILED[@]} -gt 0 ]]; then
  log "qs-verify: states that never settled: ${FAILED[*]}"
  exit 1
fi
log "qs-verify: captured $(find "$OUT" -maxdepth 1 -name '*.png' | wc -l) states into $OUT"
