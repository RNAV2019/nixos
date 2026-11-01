# Screenshots and an animated WebP walkthrough of this desktop, the same every run.
#
# Everything happens on a stage cut off from the real session:
# - a throwaway nested Hyprland, started by the live one on a hidden special workspace, with
#   one headless 1920x1200 output, so nothing shows on screen and focus never moves;
# - inside bubblewrap, where $HOME is a scratch copy of only the configs on show (no history,
#   no browser profile, no documents) and the repo is mounted read-only at ~/nixos;
# - with its own pid namespace, hostname, XDG_RUNTIME_DIR, D-Bus session and system bus, a
#   private PipeWire and fake backlight and /proc files, so `qs ipc`, `pkill`, notifications,
#   MPRIS, volume and brightness never reach the real session, and the real session's never
#   reach this one.
# Personal state is replaced by fixtures: a demo account (Ariadne, with a generated picture),
# a made-up calendar week, Wi-Fi networks, Bluetooth devices, battery, Nearby devices, clipboard
# history and a demo phone on a mock KDE Connect, a silent "now playing" track, and a frozen
# clock.
#
# The shots and the tour themselves run inside the stage (this script again, with --inner),
# since only from there can they talk to the nested shell. Each pass gets a fresh stage.
#
# Working on it: `showcase --idle --keep` leaves a stage up and prints the environment to drive
# it with (hyprctl, qs ipc, grim) from outside; touch $stage/stop to end it.
#
# usage: showcase [--shots-only | --webp-only] [--only STILL,STILL] [--out DIR] [--keep]
set -euo pipefail

self=$(realpath "${BASH_SOURCE[0]}")

# What is on show. The clock is frozen at a Wednesday mid-morning, so the week strip,
# calendar and every timestamp come out the same.
theme=ariadne
wallpaper=in-memory-of-summer-8.jpg
phone_wallpaper=in-memory-of-summer-6.jpg
clock="2026-10-21 10:08:00"
width=1920
height=1200
# The headless output is the laptop's own panel as far as the shell can tell.
output=eDP-1
# The walkthrough keeps the recording's full size and 30 fps. Lossy frames at this quality
# are indistinguishable from the source; static frames are stored lossless where smaller.
webp_quality=95
webp_fps=30
# The stills: near-lossless WebP, which GitHub draws in a README as it does a PNG.
still_quality=92

# ---- inside the stage ----

# The stills' setup and teardown functions are only ever called by name, through `still`.
# shellcheck disable=SC2329
if [ "${1:-}" = --inner ]; then
  pass=$2
  stage=$3
  shots=$stage/out/screenshots
  mkdir -p "$shots"
  cd "$HOME"
  only=""
  [ -s "$stage/only" ] && only=$(<"$stage/only")

  ipc() { qs ipc call "$@" >/dev/null; }
  dsp() { hyprctl dispatch "$1" >/dev/null; }
  # wtype sends a fresh keymap each run, and a key right behind it can be lost.
  key() { wtype -s 120 "$@"; }
  # One key, held briefly like a real press.
  press() { wtype -s 120 -P "$1" -s 40 -p "$1"; }
  type_slowly() { wtype -s 120 -d 45 -- "$1"; }
  shot() { grim -o "$output" "$shots/$1.png"; }
  hold() { sleep "$1"; }
  # tour.log: what was tried and when, for when a run comes out wrong.
  log() { echo "$(date +%T.%3N) $*" >&2; }
  focus_ws() { dsp "hl.dsp.focus({ workspace = $1 })"; }
  # mark NAME: where the tour is in the recording, for trimming it.
  mark() { log "tour +$(awk -v a="$(date +%s.%N)" -v b="${t0:-0}" 'BEGIN { printf "%.1f", a - b }') s: $1"; }
  # A click where the pointer is, through the virtual pointer protocol.
  click() { wlrctl pointer click left; }
  # The demo phone: the mock KDE Connect daemon takes one JSON operation at a time.
  ph() { dbus-send --session --print-reply --dest=org.mock.Control /control org.mock.Control.Apply string:"$1" >/dev/null; }
  # Which of the stills were asked for; all of them when none were.
  want() { [ -z "$only" ] || [[ ",$only," == *",$1,"* ]]; }

  # The pointer glides rather than jumps, so the recording reads as someone using it.
  pointer=(960 600)
  glide() {
    local x0=${pointer[0]} y0=${pointer[1]} x1=$1 y1=$2 i n=${3:-24}
    for i in $(seq 1 "$n"); do
      # ease-in-out
      local t
      t=$(awk -v i="$i" -v n="$n" 'BEGIN { t = i / n; printf "%.4f", t < .5 ? 2*t*t : 1 - (-2*t + 2)^2 / 2 }')
      dsp "hl.dsp.cursor.move({ x = $(awk -v a="$x0" -v b="$x1" -v t="$t" 'BEGIN { printf "%d", a + (b - a) * t }'), y = $(awk -v a="$y0" -v b="$y1" -v t="$t" 'BEGIN { printf "%d", a + (b - a) * t }'), absolute = true })"
      sleep 0.012
    done
    pointer=("$x1" "$y1")
  }
  # Where the pointer rests: clear of every surface, over the wallpaper.
  park() { glide 1500 760 "${1:-24}"; }
  jump() {
    dsp "hl.dsp.cursor.move({ x = $1, y = $2, absolute = true })"
    pointer=("$1" "$2")
  }

  # Wait for a new window of this class to take focus, then for it to draw.
  clients() { hyprctl clients -j | jq length; }
  active() { hyprctl activewindow -j | jq -r ".$1"; }
  wait_window() {
    local class=$1 before=$2 tries=${3:-100}
    for _ in $(seq "$tries"); do
      [ "$(clients)" -gt "$before" ] && [ "$(active class)" = "$class" ] && return 0
      sleep 0.1
    done
    return 1
  }

  # Keys can still go missing while the machine is busy (the recorder is), so anything that
  # has to happen is checked against what it changes and tried again if it didn't.
  state() {
    case "$1" in
    wallpaper) readlink -f "$HOME/.local/share/wallpaper/current" ;;
    theme) cat "$HOME/.local/state/theme/name" ;;
    esac
  }
  # pick SURFACE KEY: choose an entry in a carousel picker with KEY, then Return.
  pick() {
    local surface=$1 nav=$2 before attempt
    before=$(state "$surface")
    for attempt in 1 2 3; do
      if [ "$attempt" -gt 1 ]; then
        ipc "$surface" close
        hold 0.4
      fi
      log "pick $surface: attempt $attempt"
      ipc "$surface" toggle
      hold 1.2
      press "$nav"
      hold 0.6
      press Return
      for _ in $(seq 30); do
        [ "$(state "$surface")" != "$before" ] && return 0
        sleep 0.1
      done
    done
    echo "showcase: $surface pick did not take" >&2
    return 1
  }
  # Launch the launcher's top hit for QUERY and wait for its window.
  launch() {
    local query=$1 class=$2 before attempt
    ipc launcher toggle
    hold 0.6
    type_slowly "$query"
    hold 0.5
    before=$(clients)
    for attempt in 1 2 3; do
      log "launch $query: attempt $attempt, active $(active class)"
      press Return
      wait_window "$class" "$before" 80 && break
    done
    log "launch $query: active $(active class)"
    # The launcher closes itself on launch; make sure it has let go of the keyboard.
    ipc launcher close
  }
  # Ghostty retitles itself once fish has drawn a prompt.
  wait_prompt() {
    for _ in $(seq 50); do
      [ "$(active title)" != Ghostty ] && break
      sleep 0.1
    done
    log "prompt: $(active class) '$(active title)'"
    sleep 0.3
  }
  terminal_with() {
    local before
    before=$(clients)
    dsp 'hl.dsp.exec_cmd("ghostty")'
    wait_window com.mitchellh.ghostty "$before"
    wait_prompt
    type_slowly "$1"
    press Return
  }
  # A fresh profile opens Bitwarden's welcome tab over the page, and installing the theme
  # leaves an infobar; close the one, then reload past the other.
  browser() {
    local before title settled=0
    before=$(clients)
    dsp 'hl.dsp.exec_cmd("helium --no-first-run --no-default-browser-check --force-dark-mode https://github.com/RNAV2019/nixos")'
    wait_window helium "$before"
    for _ in $(seq 150); do
      title=$(hyprctl activewindow -j | jq -r .title)
      case "$title" in
      *Bitwarden* | *bitwarden*)
        key -M ctrl -k w -m ctrl
        settled=0
        ;;
      *RNAV2019*) settled=$((settled + 1)) ;;
      esac
      [ "$settled" -ge 20 ] && break
      sleep 0.1
    done
    press F5
    sleep 2.5
  }

  # ---- what the stage's fakes are driven by ----

  # Nearby: the stub `nearby` streams what is appended to this file, and answers a mode
  # switch (the header's Android and Apple) with that side's devices. The tabs are at the
  # panel's top.
  nearby_tab() { # KDE | ANDROID | APPLE
    case "$1" in
    KDE) jump 770 47 ;;
    ANDROID) jump 860 47 ;;
    APPLE) jump 922 47 ;;
    esac
    hold 0.4
    click
    hold 0.3
    jump 1500 760
  }
  # The demo phone, once. The shell shows it from the moment the device appears.
  phone_up() {
    ph '{"op":"device","id":"px9","name":"Pixel 9","type":"phone","battery":{"charge":78,"charging":false}}'
    ph '{"op":"cellular","dev":"px9","type":"5G","strength":3}'
    ph "{\"op\":\"sftp\",\"dev\":\"px9\",\"grant\":true,\"mount\":\"$HOME/phone-storage\"}"
    ph '{"op":"notify","dev":"px9","id":"n1","app":"Messages","title":"Maya","text":"Dinner on Friday?"}'
    ph '{"op":"notify","dev":"px9","id":"n2","app":"Calendar","title":"Design review","text":"Starts in 30 minutes"}'
  }
  # Rebuild: nix's internal-json log, appended to the file the shell tails; a live process
  # the run's ids can name keeps it from ending by itself.
  rb_log=$XDG_RUNTIME_DIR/rebuild.jsonl
  rb_pid=
  rb_id() { echo $((rb_pid * 4294967296 + $1)); }
  rb_emit() { printf '%s\n' "$1" >>"$rb_log"; }
  rb_open() {
    : >"$rb_log"
    # tail -F finds a new file within a second; the first event must not wait for it.
    sleep 1.3
    setsid sleep 600 >/dev/null 2>&1 &
    rb_pid=$!
    rb_emit "{\"action\":\"start\",\"id\":$(rb_id 1),\"level\":3,\"type\":0,\"text\":\"evaluating\",\"fields\":[]}"
    rb_emit "{\"action\":\"msg\",\"level\":3,\"msg\":\"these 12 derivations will be built:\"}"
    rb_emit "{\"action\":\"start\",\"id\":$(rb_id 2),\"level\":3,\"type\":104,\"text\":\"\",\"fields\":[]}"
    rb_emit "{\"action\":\"start\",\"id\":$(rb_id 4),\"level\":3,\"type\":105,\"text\":\"building '/nix/store/x-demo.drv'\",\"fields\":[\"/nix/store/x-demo.drv\",\"\",1,1]}"
  }
  rb_progress() { rb_emit "{\"action\":\"result\",\"id\":$(rb_id 2),\"type\":105,\"fields\":[$1,12,$2,0]}"; }
  rb_end() {
    [ -n "$rb_pid" ] && kill "$rb_pid" 2>/dev/null
    rb_pid=
  }
  # A rebuild that worked: every step done, the activities closed, then the process gone.
  rb_done() {
    rb_progress 12 0
    rb_emit "{\"action\":\"stop\",\"id\":$(rb_id 4)}"
    rb_emit "{\"action\":\"stop\",\"id\":$(rb_id 2)}"
    rb_emit "{\"action\":\"stop\",\"id\":$(rb_id 1)}"
    rb_end
  }
  # Dictation: Handy's overlay events on the socket the stage serves.
  dict() { printf '%s\n' "$1" >>"$stage/dictation.events"; }
  dict_levels() {
    local i
    for i in $(seq 40); do
      dict '{"event":"levels","levels":[0.9,0.8,0.7,0.6,0.5,0.45,0.4,0.35,0.3,0.25,0.2,0.15,0.1,0.08,0.05,0.02]}'
    done
  }
  profile_is() { echo "$1" >"$stage/profile"; }

  # Shared opening: the shell is up once its IPC answers.
  for _ in $(seq 100); do
    qs ipc call clock refresh >/dev/null 2>&1 && break
    sleep 0.1
  done
  focus_ws 1
  dsp "hl.dsp.cursor.move({ x = 960, y = 600, absolute = true })"
  sleep 2

  # ---- the stills ----

  # reset_ui: every surface closed and the pointer parked, so a still starts from the desktop.
  surfaces=(launcher control calendar nearby wallpaper theme profiles recorder phone)
  reset_ui() {
    local s
    for s in "${surfaces[@]}"; do ipc "$s" close 2>/dev/null || true; done
    ipc authpreview hide 2>/dev/null || true
    ipc activities dismissMoments 2>/dev/null || true
    jump 1500 760
    hold 1.2
  }
  # still NAME SETTLE SETUP [TEARDOWN]: from the desktop, run SETUP, give the surface SETTLE
  # seconds to come to rest and keep what is on screen as NAME.
  still() {
    local name=$1 settle=$2 setup=$3 teardown=${4:-:}
    want "$name" || return 0
    log "still $name"
    reset_ui
    $setup
    hold "$settle"
    shot "$name"
    $teardown
  }

  # Opening a panel with a view inside it: TABS Tab presses along the tiles, then Return.
  control_view() {
    ipc control toggle
    hold 1.3
    local i
    for ((i = 0; i < $1; i++)); do
      press Tab
      hold 0.25
    done
    press Return
  }
  typed() { # SURFACE TEXT: open the launcher and type
    ipc launcher toggle
    hold 1
    type_slowly "$1"
  }

  s_none() { :; }
  s_island() { glide 960 26; }
  s_launcher() { ipc launcher toggle; }
  s_calc() { typed "12*(3+4)"; }
  s_emoji() { typed ":smile"; }
  s_clipboard() { typed "@"; }
  s_control() { ipc control toggle; }
  s_control_wifi() { control_view 0; }
  s_control_audio() { control_view 1; }
  s_control_bluetooth() { control_view 2; }
  s_control_displays() { control_view 5; }
  # A second monitor for the arrangement to show.
  s_control_displays_two() {
    hyprctl output create headless DP-1 >/dev/null
    hold 0.5
    hyprctl eval 'showcase_monitor({ output = "DP-1", mode = "2560x1440@60", position = "1920x0", scale = 1 })' >/dev/null
    hold 1.5
    control_view 5
  }
  t_control_displays_two() {
    ipc control close
    hyprctl output remove DP-1 >/dev/null
    hold 1
  }
  s_calendar() { ipc calendar toggle; }
  s_nearby() { ipc nearby toggle; }
  s_nearby_apple() {
    ipc nearby toggle
    hold 1.5
    nearby_tab APPLE
  }
  t_nearby_apple() {
    ipc nearby toggle
    hold 0.8
    ipc nearby toggle
    hold 1.5
    nearby_tab ANDROID
    ipc nearby close
  }
  s_wallpaper() { ipc wallpaper toggle; }
  s_theme() { ipc theme toggle; }
  s_profiles() { ipc profiles toggle; }
  s_recorder() { ipc recorder toggle; }
  # A recording the stand-in `wl-screenrec` keeps up: the island carries the red mark.
  s_recording() {
    ipc recorder toggle
    hold 1.3
    press Return
    hold 1.2
    glide 960 26
  }
  t_recording() {
    ipc recorder toggle
    hold 1.5
  }
  s_osd() {
    ipc volume up
    hold 0.2
    ipc volume up
  }
  s_osd_brightness() {
    ipc brightness up
    echo 720 >"$stage/fake/backlight/panel/brightness"
  }
  s_rebuild() {
    rb_open
    hold 3.5
    rb_progress 5 1
  }
  t_rebuild() {
    rb_done
    # The quiet wait, then the dwell of "Switched".
    hold 12
  }
  s_dictation() {
    dict '{"event":"state","state":"streaming"}'
    hold 1.2
    dict '{"event":"ready"}'
    dict_levels
    dict '{"event":"text","committed":"Dictation shows the words as they come","tentative":" and the ones still being rewritten"}'
  }
  t_dictation() {
    dict '{"event":"hide"}'
    hold 1
  }
  s_polkit() {
    ipc authpreview ask pkexec
    hold 1.3
    type_slowly "hunter2"
  }
  s_plugged() { ipc activities plug 78 80; }
  s_wifi_signin() { ipc activities wifi portal "Labyrinth"; }
  t_wifi_signin() { ipc activities wifi full ""; }
  s_notification() { notify-send -a "nix" -i nix-snowflake -t 8000 "Rebuild finished" "Switched to generation 412 in 38 s"; }
  s_session() { ipc session toggle; }
  t_session() { ipc session toggle; }
  s_lock() {
    ipc lockpreview preview true
    hold 2.5
    ipc lockpreview password "showcase"
    hold 2
  }
  t_lock() { ipc lockpreview preview false; }
  # With the phone connected.
  s_phone() { ipc phone toggle; }
  s_nearby_phone() {
    ipc nearby send "$HOME/Pictures/Trip/lisbon.jpg"
    hold 0.6
    ipc nearby send "$HOME/Pictures/Trip/itinerary.pdf"
    hold 1.5
    nearby_tab KDE
  }
  s_sharing() {
    ph '{"op":"job_start","job":"down","dev":"px9","direction":"in","files":["alfama.jpg"],"total":2400000,"dir":"/home/ariadne/Downloads"}'
    hold 0.3
    ph '{"op":"job_update","job":"down","processed":1488000,"percent":62}'
  }
  t_sharing() {
    ph '{"op":"job_end","job":"down"}'
    hold 5
  }

  case "$pass" in
  # For working on the tour: an idle stage that stays up until $stage/stop appears.
  idle)
    # Commands for the stage arrive one line at a time on $stage/cmd (see `sx`); the helpers
    # above are all in scope, and the output comes back in $stage/cmd.out.
    mkfifo "$stage/cmd"
    until [ -e "$stage/stop" ]; do
      if read -r -t 1 line <>"$stage/cmd"; then
        eval "$line" >"$stage/cmd.out" 2>&1 || true
        touch "$stage/cmd.done"
      fi
    done
    ;;
  shots)
    # Stills without a pointer; it only hides once it next moves.
    hyprctl eval "hl.config({ cursor = { invisible = true } })" >/dev/null
    jump 961 601
    hold 0.3

    still desktop 0.5 s_none
    still island 1.4 s_island

    still launcher 1.2 s_launcher
    still launcher-calculator 1 s_calc
    still launcher-emoji 1.2 s_emoji
    still launcher-clipboard 1.2 s_clipboard

    # Earlier notifications for the control centre's list; each toast is gone by its
    # timeout, which leaves the entry behind.
    if want control; then
      notify-send -a "Messages" -t 1500 "Maya" "Dinner on Friday?"
      hold 0.4
      notify-send -a "Calendar" -t 1500 "Design review" "Starts in 30 minutes, Studio"
      hold 3
    fi
    still control 1.8 s_control
    still control-wifi 1.8 s_control_wifi
    still control-bluetooth 1.8 s_control_bluetooth
    still control-audio 1.8 s_control_audio
    still control-displays 1.8 s_control_displays_two t_control_displays_two
    still calendar 1.6 s_calendar

    still nearby 1.6 s_nearby
    still nearby-airdrop 1.8 s_nearby_apple t_nearby_apple

    still wallpaper 1.6 s_wallpaper
    still theme 1.6 s_theme
    still profiles 1.6 s_profiles
    still recorder 1.6 s_recorder
    still recording 1 s_recording t_recording

    still volume 0.8 s_osd
    still brightness 0.8 s_osd_brightness
    still dictation 1.3 s_dictation t_dictation
    still polkit 1.2 s_polkit
    still moment-plugged 1.3 s_plugged
    still moment-wifi 1.4 s_wifi_signin t_wifi_signin
    still notification 1.5 s_notification
    hold 8
    still session 1.2 s_session t_session
    still lock 0.5 s_lock t_lock
    hold 1
    still rebuild 1.4 s_rebuild t_rebuild

    if want terminal; then
      reset_ui
      terminal_with "fastfetch"
      hold 0.6
      terminal_with "hx ~/nixos/home/themes/palettes.nix"
      hold 1.5
      jump 1500 760
      shot terminal
    fi

    if want browser; then
      focus_ws 2
      browser
      hold 1
      jump 1500 760
      shot browser
    fi

    # The phone, last: it stays connected from here on, which the stills above must not see.
    focus_ws 3
    if want phone-satellite || want phone || want nearby-phone || want sharing; then
      phone_up
      hold 3
      still phone-satellite 1.5 s_island
      still phone 1.8 s_phone
      still nearby-phone 1.8 s_nearby_phone
      still sharing 1.3 s_sharing t_sharing
    fi
    ;;

  tour)
    # Off camera, open everything once: a cold launcher, picker, terminal or browser can take
    # longer than the tour waits, and a key sent too early is lost.
    for surface in launcher wallpaper theme control; do
      ipc "$surface" toggle
      hold 1.5
      ipc "$surface" close
      hold 0.5
    done
    before=$(clients)
    dsp 'hl.dsp.exec_cmd("ghostty")'
    wait_window com.mitchellh.ghostty "$before"
    wait_prompt
    dsp "hl.dsp.window.close()"
    hold 1
    # The browser waits on its own workspace, loaded, for its turn.
    focus_ws 2
    browser
    focus_ws 1
    hold 1.5

    # Lossless RGB: 4:2:0 video quantises the blurred surfaces into bands before the WebP
    # encoder ever sees them.
    wf-recorder -o "$output" -r 30 -c libx264rgb -x bgr0 -p crf=0 -p preset=ultrafast \
      -f "$stage/out/tour.mkv" >"$stage/wf-recorder.log" 2>&1 &
    recorder=$!
    t0=$(date +%s.%N)
    hold 0.8

    # The island: hover grows it into now playing, the time and the gauges.
    mark island
    glide 960 26 14
    hold 1.5
    park 14
    hold 0.2

    # Launcher, then the terminal it opens, then an editor beside it.
    mark launcher
    launch ghostty com.mitchellh.ghostty
    wait_prompt
    type_slowly "fastfetch"
    press Return
    hold 1.2
    mark editor
    terminal_with "hx ~/nixos/home/themes/palettes.nix"
    hold 1.6

    # The browser, on its own workspace.
    mark browser
    focus_ws 2
    hold 1.6

    # An empty workspace for the shell's own surfaces: the control centre and its Wi-Fi view.
    mark control
    focus_ws 3
    hold 0.4
    ipc control toggle
    hold 1.2
    press Return
    hold 1.3
    ipc control close
    hold 0.3

    # A rebuild passing by, as a pill growing out of the island.
    mark rebuild
    rb_open
    hold 0.4
    rb_progress 4 1
    hold 0.6
    rb_progress 8 1
    hold 0.6
    rb_done
    hold 4.2

    # The phone buds out of the island, and opens into its panel.
    mark phone
    phone_up
    hold 1.8
    ipc phone toggle
    hold 2
    ipc phone close
    hold 0.3

    # Wallpaper, then the whole desktop recoloured: Rose Pine and back to Ariadne.
    mark wallpaper
    pick wallpaper Home
    hold 1.4
    mark theme
    pick theme Home
    hold 1.8
    pick theme End
    hold 1.5

    # The lock screen, typed into, and out again.
    mark lock
    ipc lockpreview preview true
    hold 1.4
    for p in s sh sho show showc showca showcas showcase; do
      ipc lockpreview password "$p"
      sleep 0.09
    done
    hold 1.2
    ipc lockpreview preview false
    hold 1
    mark end

    kill -INT "$recorder"
    wait "$recorder" || true
    ;;
  esac
  touch "$stage/done"
  exit 0
fi

# ---- outside: build the stage, run a pass in it, collect the results ----

usage() { sed -n 's/^# usage: //p' "$self"; }

mode=all
keep=0
repo=${SHOWCASE_REPO:-$HOME/nixos}
out=""
only=""
while [ $# -gt 0 ]; do
  case "$1" in
  --shots-only) mode=shots ;;
  --webp-only) mode=webp ;;
  --only)
    only=$2
    mode=shots
    shift
    ;;
  --out)
    out=$2
    shift
    ;;
  --keep) keep=1 ;;
  --idle) mode=idle ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
  esac
  shift
done
out=$(realpath -m "${out:-$repo}")

: "${SHOWCASE_FIXTURES:?}" "${SHOWCASE_PYTHON:?}" "${SHOWCASE_MOCK_KDECONNECTD:?}"
fixtures=$SHOWCASE_FIXTURES

[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || {
  echo "showcase: run this from inside a Hyprland session" >&2
  exit 1
}
[ -f "$repo/flake.nix" ] || {
  echo "showcase: no repo at $repo (set SHOWCASE_REPO)" >&2
  exit 1
}

# The nested compositor has to be the same build as the live one, which the config is for.
hyprbin=$(dirname "$(readlink -f "$(command -v hyprctl)")")
themedir=$(sed -n "s|^ *$theme) dir=\(/nix/store/[^ ]*\) ;;\$|\1|p" "$(readlink -f "$(command -v theme-switch)")")
[ -d "$themedir" ] || {
  echo "showcase: theme-switch does not know $theme" >&2
  exit 1
}
emoji=$(readlink -f "$HOME/.local/share/quickshell/emoji.tsv")

stage=""
unit=""
cleanup() {
  [ -n "$unit" ] && systemctl --user stop "$unit.scope" 2>/dev/null || true
  if [ -n "$stage" ]; then
    if [ "$keep" = 1 ]; then
      echo "showcase: stage kept at $stage"
    else
      chmod -R u+w "$stage" 2>/dev/null || true
      rm -rf "$stage"
    fi
  fi
}
trap cleanup EXIT

# Replace one exact expression everywhere in a file, and fail loudly if the code has moved on.
demo_label() {
  local file=$1 from=$2 to=$3
  grep -qF -- "$from" "$file" || {
    echo "showcase: $(basename "$file") no longer contains: $from" >&2
    exit 1
  }
  FROM=$from TO=$to perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
}

build_home() {
  local home=$1 c shell
  mkdir -p "$home/.config/hypr" "$home/.config/fastfetch" "$home/.local/state/theme" \
    "$home/.local/state/shell" "$home/.local/share/wallpaper" "$home/Pictures" "$home/nixos"
  for c in ghostty fish helix fontconfig gtk-3.0 gtk-4.0 starship.toml; do
    [ -e "$HOME/.config/$c" ] && cp -rL "$HOME/.config/$c" "$home/.config/"
  done
  rm -f "$home/.config/fish/fish_variables"
  # Helix's Steel plugins live outside its config directory.
  mkdir -p "$home/.local/share"
  cp -rL "$HOME/.local/share/steel" "$home/.local/share/"
  cp -L "$HOME/.config/hypr/hyprland.lua" "$home/.config/hypr/"
  cp "$fixtures/fastfetch.jsonc" "$home/.config/fastfetch/config.jsonc"
  # Somewhere on the PATH fish builds for itself.
  mkdir -p "$home/.nix-profile/bin"
  ln -s "$(command -v fastfetch)" "$home/.nix-profile/bin/fastfetch"

  # The shell from the working tree. What it reads from the machine's own surroundings
  # (NetworkManager, BlueZ, UPower) is pointed at the made-up devices of DemoDevices.qml.
  shell=$home/.config/quickshell
  cp -rL "$repo/home/quickshell" "$shell"
  chmod -R u+w "$shell"
  cp "$fixtures/DemoDevices.qml" "$shell/Services/"
  demo_label "$shell/Services/NetworkInfo.qml" 'Networking.devices.values' 'DemoDevices.devices'
  demo_label "$shell/Control/WifiView.qml" 'Networking.wifiEnabled' 'DemoDevices.wifiEnabled'
  demo_label "$shell/Control/WifiView.qml" 'Networking.wifiHardwareEnabled' 'true'
  demo_label "$shell/Control/HomeView.qml" 'Networking.wifiEnabled' 'DemoDevices.wifiEnabled'
  demo_label "$shell/Control/HomeView.qml" 'Bluetooth.defaultAdapter' 'DemoDevices.adapter'
  demo_label "$shell/Control/BluetoothView.qml" 'Bluetooth.defaultAdapter' 'DemoDevices.adapter'
  demo_label "$shell/Control/BluetoothView.qml" 'import qs.Control' $'import qs.Control\nimport qs.Services'
  demo_label "$shell/Services/Battery.qml" 'UPower.displayDevice' 'DemoDevices.battery'
  demo_label "$shell/Services/AppSearch.qml" 'if (e.noDisplay || !e.name)' 'if (e.noDisplay || !e.name || DemoDevices.apps.indexOf(String(e.id)) < 0)'
  demo_label "$shell/Services/Rebuild.qml" 'Date.now()' 'DemoDevices.elapsed'

  ln -s "$themedir" "$home/.local/state/theme/current"
  echo "$theme" >"$home/.local/state/theme/name"
  cp -rL "$repo/backgrounds" "$home/Pictures/backgrounds"
  ln -s "$HOME/Pictures/backgrounds/$theme/$wallpaper" "$home/.local/share/wallpaper/current"
  ln -s "$HOME/Pictures/backgrounds/$theme/$wallpaper" "$home/.local/share/wallpaper/$theme"
  ln -s "$HOME/Pictures/backgrounds/rose-pine/nbhd_v2.jpg" "$home/.local/share/wallpaper/rose-pine"

  # The demo account's picture: an initial on a soft gradient, drawn here so it is no one's.
  magick -size 512x512 gradient:'#7fe0c8-#2f7f86' -stroke '#f4fffb' -strokewidth 38 \
    -fill none \
    -draw 'stroke-linecap round stroke-linejoin round polyline 150,390 256,128 362,390' \
    -draw 'stroke-linecap round line 190,305 322,305' "jpg:$home/.face"
  # The picture drawn on the demo phone's preview.
  magick "$repo/backgrounds/$theme/$phone_wallpaper" -resize 1080x -quality 88 \
    "$home/.local/state/shell/phone-wallpaper-demo.jpg"
  echo "$HOME/.local/state/shell/phone-wallpaper-demo.jpg" >"$home/.local/state/shell/phone-wallpaper"
  # What the phone's storage and the pictures folder hold, for the file pickers.
  mkdir -p "$home/phone-storage" "$home/Pictures/Trip"
  local i=0 name
  for name in lisbon.jpg alfama.jpg tram.jpg; do
    i=$((i + 1))
    magick -size 1600x1000 "gradient:$(printf '#%02x7c9c-#e0%02x70' $((40 + i * 40)) $((120 - i * 20)))" \
      -fill '#f4e9c9' -draw "circle $((400 + i * 300)),330 $((400 + i * 300)),470" "$home/Pictures/Trip/$name"
  done
  head -c 612000 /dev/zero >"$home/Pictures/Trip/itinerary.pdf"

  # PipeWire with a speaker, a headset and a microphone of our own making, so the audio views
  # draw these and never the machine's.
  mkdir -p "$home/.config/pipewire/pipewire.conf.d" "$home/.config/wireplumber/wireplumber.conf.d"
  cat >"$home/.config/pipewire/pipewire.conf.d/10-showcase.conf" <<'EOF'
context.objects = [
  { factory = adapter
    args = { factory.name = support.null-audio-sink node.name = "speakers" priority.session = 2000
             node.description = "Speakers" media.class = Audio/Sink
             object.linger = true audio.position = [ FL FR ] } }
  { factory = adapter
    args = { factory.name = support.null-audio-sink node.name = "buds" priority.session = 1000
             node.description = "Pixel Buds Pro" media.class = Audio/Sink
             object.linger = true audio.position = [ FL FR ] } }
  { factory = adapter
    args = { factory.name = support.null-audio-sink node.name = "mic" priority.session = 2000
             node.description = "Internal Microphone" media.class = Audio/Source
             object.linger = true audio.position = [ FL FR ] } }
]
EOF
  cat >"$home/.config/wireplumber/wireplumber.conf.d/10-showcase.conf" <<'EOF'
wireplumber.profiles = {
  main = {
    hardware.audio = disabled
    hardware.bluetooth = disabled
    hardware.video-capture = disabled
  }
}
EOF
  # Copies out of the store are read-only, which would stop cleanup removing them.
  chmod -R u+w "$home"
}

# One pass on a fresh stage: shots or tour.
run_pass() {
  local pass=$1
  stage=$(mktemp -d /tmp/showcase.XXXXXX)
  unit=$(basename "$stage")
  local home=$stage/home run=$stage/run
  mkdir -p "$home" "$run" "$stage/bin" "$run/handy"
  chmod 700 "$run"
  build_home "$home"
  printf '%s' "$only" >"$stage/only"

  # Fixtures the shell finds on PATH in place of the real tools.
  install -m755 "$fixtures/ical-agenda" "$fixtures/nearby" "$fixtures/brightnessctl" \
    "$fixtures/powerprofilesctl" "$fixtures/wl-screenrec" "$fixtures/cliphist" "$fixtures/systemd-run" "$stage/bin/"
  : >"$stage/nearby.events"
  : >"$stage/dictation.events"
  echo balanced >"$stage/profile"
  # Cover art for the demo track: a square from the middle of the wallpaper.
  ffmpeg -v error -i "$repo/backgrounds/$theme/$wallpaper" \
    -vf "crop=min(iw\,ih):min(iw\,ih),scale=512:512" -y "$stage/cover.jpg"

  # What the shell reads from sysfs and /proc, as fixed files, so a brightness key moves a
  # number here and not the laptop's backlight, and the gauges hold still.
  mkdir -p "$stage/fake/backlight/panel" "$stage/fake/leds/showcase::kbd_backlight" "$stage/fake/proc"
  echo 960 >"$stage/fake/backlight/panel/max_brightness"
  echo 480 >"$stage/fake/backlight/panel/brightness"
  echo 3 >"$stage/fake/leds/showcase::kbd_backlight/max_brightness"
  echo 1 >"$stage/fake/leds/showcase::kbd_backlight/brightness"
  echo 'cpu  100 0 100 800 0 0 0 0 0 0' >"$stage/fake/proc/stat"
  printf 'MemTotal:       16000000 kB\nMemFree:         6000000 kB\nMemAvailable:    8000000 kB\n' \
    >"$stage/fake/proc/meminfo"
  echo "Fast [Standard] Long_Life" >"$stage/fake/charge_types"

  # The demo account: the same uid under another name, which is all `getent` and whoami read.
  awk -F: -v OFS=: -v uid="$(id -u)" -v home="$HOME" \
    '$3 == uid { $1 = "ariadne"; $5 = "Ariadne"; $6 = home } { print }' /etc/passwd >"$stage/passwd"

  # A system bus of its own and empty, so NetworkManager, BlueZ, polkit and logind answer
  # nothing, and nothing in the stage can reach the real ones.
  cat >"$stage/system.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>system</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
EOF

  # The real config without its session hooks, monitors or plugins, then ours. The nested
  # window's own output is disabled once the headless one exists, which takes a reload.
  cat >"$home/.config/hypr/nested.lua" <<EOF
local on, monitor, config = hl.on, hl.monitor, hl.config
hl.on = function() end
hl.config = function(t)
  if type(t) == "table" then t.plugin = nil end
  return config(t)
end
hl.monitor = function() end
showcase_monitor = monitor
pcall(function() hl.plugin.load = function() end end)
dofile("$HOME/.config/hypr/hyprland.lua")
monitor({ output = "$output", mode = "${width}x${height}@60", position = "0x0", scale = 1 })
for _, m in ipairs(hl.get_monitors()) do
  if m.name == "$output" then monitor({ output = "WAYLAND-1", disabled = true }) end
end
config({
  ecosystem = { no_update_news = true, no_donation_nag = true },
  misc = { disable_watchdog_warning = true },
})
on("hyprland.start", function() hl.exec_cmd("$stage/session.sh") end)
EOF

  cat >"$stage/session.sh" <<EOF
#!/bin/sh
exec >>"$stage/session.log" 2>&1
hyprctl output create headless $output
sleep 0.5
hyprctl reload
awww-daemon &
for _ in \$(seq 50); do awww query >/dev/null 2>&1 && break; sleep 0.1; done
awww img --transition-type none "\$HOME/.local/share/wallpaper/current"
pipewire &
sleep 1
wireplumber &
for _ in \$(seq 100); do
  wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && wpctl inspect @DEFAULT_AUDIO_SOURCE@ >/dev/null 2>&1 && break
  sleep 0.2
done
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.40
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.80
socat "UNIX-LISTEN:\$XDG_RUNTIME_DIR/handy/overlay.sock,fork" "EXEC:tail -n0 -F $stage/dictation.events" &
"$SHOWCASE_PYTHON" "$fixtures/mpris-player.py" "$stage/cover.jpg" &
"$SHOWCASE_PYTHON" "$SHOWCASE_MOCK_KDECONNECTD" "$stage/phone-calls.log" &
: >"\$XDG_RUNTIME_DIR/quickshell-secured-\$HYPRLAND_INSTANCE_SIGNATURE"
export SHOWCASE_NEARBY="$stage/nearby.events" SHOWCASE_PROFILE="$stage/profile"
export SHOWCASE_DAY="${clock%% *}"
export QUICKSHELL_CHARGE_TYPES="$stage/fake/charge_types" QS_EMOJI_DATA="$emoji"
PATH="$stage/bin:\$PATH" datefudge --static "$clock" qs -p "\$HOME/.config/quickshell" >"$stage/qs.log" 2>&1 &
bash "$self" --inner $pass "$stage" >"$stage/tour.log" 2>&1 || touch "$stage/failed"
EOF

  # Everything in the sandbox starts here: the private system bus, then the session bus and
  # the compositor.
  cat >"$stage/boot.sh" <<EOF
#!/bin/sh
DBUS_SYSTEM_BUS_ADDRESS=\$(dbus-daemon --config-file="$stage/system.conf" --fork --print-address)
export DBUS_SYSTEM_BUS_ADDRESS
exec dbus-run-session -- "$hyprbin/Hyprland" -c "$HOME/.config/hypr/nested.lua"
EOF

  # Started by the live compositor, so it runs in the real session (not whatever sandbox
  # this script was called from), in a scope of its own so cleanup can stop all of it.
  local rt=$XDG_RUNTIME_DIR wl=$WAYLAND_DISPLAY
  cat >"$stage/launch.sh" <<EOF
#!/bin/sh
exec systemd-run --user --scope --collect --quiet --unit="$unit" \\
  env -u HYPRLAND_INSTANCE_SIGNATURE -u NOTIFY_SOCKET -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS \\
  -u DBUS_SYSTEM_BUS_ADDRESS -u QS_CONFIG_PATH -u QS_CONFIG_NAME \\
  PATH="$PATH" WAYLAND_DISPLAY=parent-wayland HYPRLAND_NO_SD_VARS=1 LIBSEAT_BACKEND=seatd SEATD_SOCK=/nonexistent \\
  USER=ariadne LOGNAME=ariadne \\
  bwrap --dev-bind / / --unshare-pid --unshare-uts --hostname labyrinth --proc /proc --die-with-parent \\
    --bind "$home" "$HOME" --ro-bind "$repo" "$HOME/nixos" \\
    --bind "$run" "$rt" --bind "$rt/$wl" "$rt/parent-wayland" \\
    --ro-bind "$stage/passwd" /etc/passwd --tmpfs /run/nscd \\
    --bind "$stage/fake/backlight" /sys/class/backlight --bind "$stage/fake/leds" /sys/class/leds \\
    --bind "$stage/fake/proc/stat" /proc/stat --bind "$stage/fake/proc/meminfo" /proc/meminfo \\
    "$stage/boot.sh" >"$stage/hyprland.log" 2>&1
EOF
  chmod +x "$stage/session.sh" "$stage/boot.sh" "$stage/launch.sh"

  echo "showcase: $pass pass"
  # Now and then the nested Hyprland hangs before its first frame and never runs
  # session.sh; a fresh start gets past it.
  local attempt
  for attempt in 1 2 3 4 5; do
    hyprctl dispatch "hl.dsp.exec_cmd('$stage/launch.sh', { workspace = 'special:showcase silent', no_initial_focus = true })" >/dev/null
    for _ in $(seq 40); do
      [ -e "$stage/session.log" ] && break 2
      sleep 0.5
    done
    echo "showcase: the nested compositor hung on start; restarting it" >&2
    systemctl --user stop "$unit.scope" 2>/dev/null || true
    sleep 1
    rm -rf "${run:?}"/* "$stage/hyprland.log"
    mkdir -p "$run/handy"
  done
  [ -e "$stage/session.log" ] || {
    echo "showcase: the nested compositor would not start" >&2
    keep=1
    exit 1
  }
  if [ "$mode" = idle ]; then
    local sig
    sig=$(basename "$(find "$run/hypr" -mindepth 1 -maxdepth 1 -type d | head -n1)")
    echo "showcase: stage up at $stage; drive it with:"
    echo "  export XDG_RUNTIME_DIR=$run HYPRLAND_INSTANCE_SIGNATURE=$sig WAYLAND_DISPLAY=wayland-1"
    echo "  (and touch $stage/stop to end it)"
  fi
  local waited=0
  until [ -e "$stage/done" ] || [ -e "$stage/failed" ]; do
    sleep 0.5
    waited=$((waited + 1))
    if [ "$waited" -gt 1200 ] && [ "$mode" != idle ]; then
      echo "showcase: the $pass pass timed out" >&2
      touch "$stage/failed"
    fi
  done
  if [ -e "$stage/failed" ]; then
    echo "showcase: the $pass pass failed; logs kept in $stage" >&2
    tail -n 20 "$stage/tour.log" >&2 || true
    keep=1
    exit 1
  fi
}

finish_pass() {
  systemctl --user stop "$unit.scope" 2>/dev/null || true
  if [ "$keep" = 1 ]; then
    echo "showcase: stage kept at $stage"
  else
    chmod -R u+w "$stage" 2>/dev/null || true
    rm -rf "$stage"
  fi
  stage=""
  unit=""
}

if [ "$mode" = idle ]; then
  run_pass idle
  exit 0
fi

if [ "$mode" = shots ] || [ "$mode" = all ]; then
  run_pass shots
  mkdir -p "$out/screenshots"
  if [ -z "$only" ]; then
    rm -f "$out/screenshots"/*.png "$out/screenshots"/*.webp "$out/screenshots"/.*.png
  fi
  # Near-lossless WebP: -sharp_yuv keeps small coloured text crisp through its 4:2:0 frames.
  for png in "$stage/out/screenshots/"*.png; do
    cwebp -quiet -q "$still_quality" -m 6 -sharp_yuv -mt "$png" -o "$out/screenshots/$(basename "$png" .png).webp"
  done
  echo "showcase: $(find "$stage/out/screenshots" -name '*.png' | wc -l) screenshots in $out/screenshots ($(du -ch "$out/screenshots"/*.webp | tail -n1 | cut -f1))"
  finish_pass
fi

if [ "$mode" = webp ] || [ "$mode" = all ]; then
  run_pass tour
  # RGB frames straight to libwebp: -sharp_yuv keeps small coloured text crisp through its
  # 4:2:0 lossy frames, and -mixed lets unchanged UI fall back to lossless.
  mkdir -p "$stage/frames"
  ffmpeg -v error -i "$stage/out/tour.mkv" -pix_fmt rgb24 -vf "fps=$webp_fps" "$stage/frames/%05d.png"
  {
    echo "-loop 0 -mixed -sharp_yuv"
    echo "-d $((1000 / webp_fps)) -lossy -q $webp_quality -m 6"
    find "$stage/frames" -name '*.png' | sort
    echo "-o $out/showcase.webp"
  } | tr '\n' ' ' >"$stage/img2webp.args"
  img2webp "$stage/img2webp.args" >/dev/null
  echo "showcase: $(du -h "$out/showcase.webp" | cut -f1) webp at $out/showcase.webp"
  finish_pass
fi
