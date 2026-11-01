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
  for k in launcher control wallpaper profiles calendar nearby recorder theme phone; do
    qsipc "$k" close >/dev/null 2>&1
  done
  qsipc authpreview hide >/dev/null 2>&1
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

setup_phone_satellite() { :; }
setup_phone_satellite_card() { cursor 960 26; }
setup_phone_satellite_hover() { cursor 1045 26; }
setup_phone_satellite_low() { ph '{"op":"battery","dev":"s24","charge":14,"charging":false}'; }
teardown_phone_low() { ph '{"op":"battery","dev":"s24","charge":78,"charging":false}'; }
setup_phone_satellite_osd() { setup_osd_volume; }
setup_panel_phone() { open_panel phone; }
setup_panel_phone_hover_note() {
  open_panel phone
  sleep 1.6
  cursor 960 524
}
setup_panel_phone_ringing() {
  open_panel phone
  sleep 1.6
  cursor 770 288
  sleep 0.3
  click
}

# Screen positions in the phone panel (opened at 700, 8): the wallpaper disc, and the Browse button.
PH_DISC_X=823 PH_DISC_Y=241
PH_BROWSE_X=1004 PH_BROWSE_Y=288
# In the 960 px picker (opened at 480, 8): the Phone and Laptop cells, and the empty state's button.
PK_PHONE_X=1331 PK_LAPTOP_X=1389 PK_SWITCH_Y=36
PK_BROWSE_LAPTOP_X=960 PK_BROWSE_LAPTOP_Y=245

setup_phone_low() { ph '{"op":"battery","dev":"s24","charge":14,"charging":false}'; open_panel phone; }
setup_phone_mobile_off() {
  ph '{"op":"cellular","dev":"s24","type":"","strength":-1}'
  sleep 1
  open_panel phone
}
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

# ---- the run ----

{
  echo "scale=$QSV_SCALE"
  echo "theme=$QSV_THEME"
  echo "date=$(date +%F)"
  echo "source=$QSV_SRC"
  echo "commit=$(git -C "$QSV_SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} >"$OUT/meta.txt"

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
  shot panel-phone-hover-note 1.0 0.3 setup_panel_phone_hover_note
  shot panel-phone-ringing 1.0 0.3 setup_panel_phone_ringing
  shot panel-phone-low 1.8 0.3 setup_phone_low teardown_phone_low
  shot panel-phone-mobile-off 1.8 0.3 setup_phone_mobile_off teardown_phone_mobile
  shot panel-phone-browse-blocked 1.8 0.3 setup_phone_browse_blocked teardown_phone_access
  shot panel-phone-picker-phone 1.0 0.3 setup_phone_picker_phone
  shot panel-phone-picker-laptop 1.0 0.3 setup_phone_picker_laptop
  shot panel-phone-picker-blocked 1.0 0.3 setup_phone_picker_blocked teardown_phone_access
  check phone-browse-nautilus browse_opens_nautilus
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
fi

reset_ui
[[ -n $ONLY || ${#FAILED[@]} -gt 0 ]] || rm -rf "$OUT/unstable"
if [[ ${#FAILED[@]} -gt 0 ]]; then
  log "qs-verify: states that never settled: ${FAILED[*]}"
  exit 1
fi
log "qs-verify: captured $(find "$OUT" -maxdepth 1 -name '*.png' | wc -l) states into $OUT"
