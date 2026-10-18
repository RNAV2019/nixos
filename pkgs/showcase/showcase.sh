# Screenshots and an animated WebP walkthrough of this desktop, the same every run.
#
# Everything happens on a stage cut off from the real session:
# - a throwaway nested Hyprland, started by the live one on a hidden special workspace, with
#   one headless 1920x1200 output, so nothing shows on screen and focus never moves;
# - inside bubblewrap, where $HOME is a scratch copy of only the configs on show (no history,
#   no browser profile, no documents) and the repo is mounted read-only at ~/nixos;
# - with its own pid namespace, XDG_RUNTIME_DIR and D-Bus session, so `qs ipc`, `pkill`,
#   notifications and MPRIS never reach the real session, and the real session's never
#   reach this one.
# Personal state is replaced by fixtures: a made-up calendar week, demo Nearby devices, a
# silent "now playing" track, a frozen clock, and demo Wi-Fi/Bluetooth names.
#
# The tour itself runs inside the stage (this script again, with --inner), since only from
# there can it talk to the nested shell. Each pass gets a fresh stage.
#
# usage: showcase [--shots-only | --webp-only] [--out DIR] [--keep]
set -euo pipefail

self=$(realpath "${BASH_SOURCE[0]}")

# What is on show. The clock is frozen at a Wednesday mid-morning, so the week strip,
# calendar and every timestamp come out the same.
theme=ariadne
wallpaper=in-memory-of-summer-8.jpg
clock="2026-10-21 10:08:00"
width=1920
height=1200
output=SHOWCASE
# The walkthrough keeps the recording's full size and 30 fps. Lossy frames at this quality
# are indistinguishable from the source; static frames are stored lossless where smaller.
webp_quality=95
webp_fps=30

# ---- inside the stage ----

if [ "${1:-}" = --inner ]; then
  pass=$2
  stage=$3
  shots=$stage/out/screenshots
  mkdir -p "$shots"
  cd "$HOME"

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

  # The pointer glides rather than jumps, so the recording reads as someone using it.
  pointer=(960 600)
  glide() {
    local x0=${pointer[0]} y0=${pointer[1]} x1=$1 y1=$2 i n=24
    for i in $(seq 1 $n); do
      # ease-in-out
      local t
      t=$(awk -v i="$i" -v n="$n" 'BEGIN { t = i / n; printf "%.4f", t < .5 ? 2*t*t : 1 - (-2*t + 2)^2 / 2 }')
      dsp "hl.dsp.cursor.move({ x = $(awk -v a="$x0" -v b="$x1" -v t="$t" 'BEGIN { printf "%d", a + (b - a) * t }'), y = $(awk -v a="$y0" -v b="$y1" -v t="$t" 'BEGIN { printf "%d", a + (b - a) * t }'), absolute = true })"
      sleep 0.012
    done
    pointer=("$x1" "$y1")
  }
  park() { glide 1500 760; }

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
    dsp 'hl.dsp.exec_cmd("helium --no-first-run --no-default-browser-check https://github.com/RNAV2019/nixos")'
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

  # Shared opening: the shell is up once its IPC answers.
  for _ in $(seq 100); do
    qs ipc call clock refresh >/dev/null 2>&1 && break
    sleep 0.1
  done
  focus_ws 1
  dsp "hl.dsp.cursor.move({ x = 960, y = 600, absolute = true })"
  sleep 2

  case "$pass" in
  # For working on the tour: an idle stage that stays up until $stage/stop appears.
  idle)
    until [ -e "$stage/stop" ]; do sleep 0.5; done
    ;;
  shots)
    # Stills without a pointer; it only hides once it next moves.
    hyprctl eval "hl.config({ cursor = { invisible = true } })" >/dev/null
    glide 961 601
    hold 0.3
    shot desktop

    glide 960 26
    hold 1.2
    shot island
    park
    hold 1

    ipc launcher toggle
    hold 0.8
    shot launcher
    ipc launcher close

    for surface in control calendar nearby wallpaper theme profiles recorder; do
      ipc "$surface" toggle
      hold 1.6
      shot "$surface"
      ipc "$surface" close
      hold 0.8
    done

    ipc session toggle
    hold 1
    shot session
    ipc session toggle
    hold 0.8

    notify-send -a "nix" -i nix-snowflake "Rebuild finished" "Switched to generation 412 in 38 s"
    hold 1.5
    shot notification
    hold 5

    ipc lockpreview preview true
    hold 2.5
    ipc lockpreview password "showcase"
    hold 0.8
    shot lockscreen
    ipc lockpreview preview false
    hold 1

    terminal_with "fastfetch"
    hold 0.6
    terminal_with "hx ~/nixos/flake.nix"
    hold 1.5
    shot terminal

    focus_ws 2
    browser
    hold 1
    shot browser
    ;;

  tour)
    # Off camera, open everything once: a cold launcher, picker or terminal can take longer
    # than the tour waits, and a key sent too early is lost.
    for surface in launcher wallpaper theme; do
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
    hold 1.5

    # Lossless RGB: 4:2:0 video quantises the blurred surfaces into bands before the WebP
    # encoder ever sees them.
    wf-recorder -o "$output" -r 30 -c libx264rgb -x bgr0 -p crf=0 -p preset=ultrafast \
      -f "$stage/out/tour.mkv" >"$stage/wf-recorder.log" 2>&1 &
    recorder=$!
    hold 1.5

    # The island: hover grows it into the week, now playing and system gauges.
    glide 960 26
    hold 2.6
    park
    hold 0.6

    # Launcher, then the terminal it opens, then an editor beside it.
    launch ghostty com.mitchellh.ghostty
    wait_prompt
    type_slowly "fastfetch"
    press Return
    hold 1.8
    terminal_with "hx ~/nixos/flake.nix"
    hold 2.2

    # The browser on its own workspace.
    focus_ws 2
    browser
    hold 1.5

    # An empty workspace for the shell's own surfaces.
    focus_ws 3
    hold 0.8
    ipc control toggle
    hold 2.4
    ipc control close
    hold 0.5
    ipc calendar toggle
    hold 2.2
    ipc calendar close
    hold 0.5
    notify-send -a "nix" -i nix-snowflake "Rebuild finished" "Switched to generation 412 in 38 s"
    hold 3
    ipc nearby toggle
    hold 3
    ipc nearby close
    hold 0.5

    # Wallpaper, then the whole desktop recoloured: Rose Pine and back to Ariadne.
    pick wallpaper Home
    hold 2.2
    pick theme Home
    hold 2.6
    pick theme End
    hold 2.2

    ipc profiles toggle
    hold 1.6
    ipc profiles close
    hold 0.4
    ipc session toggle
    hold 1.6
    ipc session toggle
    hold 0.6

    ipc lockpreview preview true
    hold 2
    for p in s sh sho show showc showca showcas showcase; do
      ipc lockpreview password "$p"
      sleep 0.09
    done
    hold 1.4
    ipc lockpreview preview false
    hold 1.5

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
while [ $# -gt 0 ]; do
  case "$1" in
  --shots-only) mode=shots ;;
  --webp-only) mode=webp ;;
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

: "${SHOWCASE_FIXTURES:?}" "${SHOWCASE_PYTHON:?}"
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

stage=""
unit=""
cleanup() {
  [ -n "$unit" ] && systemctl --user stop "$unit.scope" 2>/dev/null || true
  if [ -n "$stage" ]; then
    if [ "$keep" = 1 ]; then
      echo "showcase: stage kept at $stage"
    else
      rm -rf "$stage"
    fi
  fi
}
trap cleanup EXIT

# Replace one exact expression, and fail loudly if the code has moved on.
demo_label() {
  local file=$1 from=$2 to=$3
  grep -qF -- "$from" "$file" || {
    echo "showcase: $(basename "$file") no longer contains: $from" >&2
    exit 1
  }
  FROM=$from TO=$to perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
}

build_home() {
  local home=$1 c
  mkdir -p "$home/.config/hypr" "$home/.config/fastfetch" "$home/.local/state/theme" \
    "$home/.local/share/wallpaper" "$home/Pictures" "$home/nixos"
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

  # The shell from the working tree, with the two labels that name real devices swapped.
  cp -rL "$repo/home/quickshell" "$home/.config/quickshell"
  demo_label "$home/.config/quickshell/Control/HomeView.qml" \
    'NetworkInfo.activeNetwork ? NetworkInfo.activeNetwork.name : "Not connected"' '"Labyrinth"'
  demo_label "$home/.config/quickshell/Control/HomeView.qml" \
    'root.connectedDevice ? root.connectedDevice.name : "On"' '"Pixel Buds Pro"'

  ln -s "$themedir" "$home/.local/state/theme/current"
  echo "$theme" >"$home/.local/state/theme/name"
  cp -rL "$repo/backgrounds" "$home/Pictures/backgrounds"
  ln -s "$HOME/Pictures/backgrounds/$theme/$wallpaper" "$home/.local/share/wallpaper/current"
  ln -s "$HOME/Pictures/backgrounds/$theme/$wallpaper" "$home/.local/share/wallpaper/$theme"
  ln -s "$HOME/Pictures/backgrounds/rose-pine/nbhd_v2.jpg" "$home/.local/share/wallpaper/rose-pine"
  ln -s "$HOME/nixos/profile.jpg" "$home/.face"
  # Copies out of the store are read-only, which would stop cleanup removing them.
  chmod -R u+w "$home"
}

# One pass on a fresh stage: shots or tour.
run_pass() {
  local pass=$1
  stage=$(mktemp -d /tmp/showcase.XXXXXX)
  unit=$(basename "$stage")
  local home=$stage/home run=$stage/run
  mkdir -p "$home" "$run" "$stage/bin"
  chmod 700 "$run"
  build_home "$home"

  # Fixtures the shell finds on PATH in place of the real tools.
  install -m755 "$fixtures/ical-agenda" "$fixtures/nearby" "$stage/bin/"
  # Cover art for the demo track: a square from the middle of the wallpaper.
  ffmpeg -v error -i "$repo/backgrounds/$theme/$wallpaper" \
    -vf "crop=min(iw\,ih):min(iw\,ih),scale=512:512" -y "$stage/cover.jpg"

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
"$SHOWCASE_PYTHON" "$fixtures/mpris-player.py" "$stage/cover.jpg" &
: >"\$XDG_RUNTIME_DIR/quickshell-secured-\$HYPRLAND_INSTANCE_SIGNATURE"
PATH="$stage/bin:\$PATH" datefudge --static "$clock" qs -p "\$HOME/.config/quickshell" >"$stage/qs.log" 2>&1 &
bash "$self" --inner $pass "$stage" >"$stage/tour.log" 2>&1 || touch "$stage/failed"
EOF

  # Started by the live compositor, so it runs in the real session (not whatever sandbox
  # this script was called from), in a scope of its own so cleanup can stop all of it.
  local rt=$XDG_RUNTIME_DIR wl=$WAYLAND_DISPLAY
  cat >"$stage/launch.sh" <<EOF
#!/bin/sh
exec systemd-run --user --scope --collect --quiet --unit="$unit" \\
  env -u HYPRLAND_INSTANCE_SIGNATURE -u NOTIFY_SOCKET -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS \\
  -u QS_CONFIG_PATH -u QS_CONFIG_NAME \\
  PATH="$PATH" WAYLAND_DISPLAY=parent-wayland HYPRLAND_NO_SD_VARS=1 LIBSEAT_BACKEND=seatd SEATD_SOCK=/nonexistent \\
  bwrap --dev-bind / / --unshare-pid --proc /proc --die-with-parent \\
    --bind "$home" "$HOME" --ro-bind "$repo" "$HOME/nixos" \\
    --bind "$run" "$rt" --bind "$rt/$wl" "$rt/parent-wayland" --bind "$rt/pipewire-0" "$rt/pipewire-0" \\
    dbus-run-session -- "$hyprbin/Hyprland" -c "$HOME/.config/hypr/nested.lua" >"$stage/hyprland.log" 2>&1
EOF
  chmod +x "$stage/session.sh" "$stage/launch.sh"

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
  done
  [ -e "$stage/session.log" ] || {
    echo "showcase: the nested compositor would not start" >&2
    keep=1
    exit 1
  }
  local waited=0
  until [ -e "$stage/done" ] || [ -e "$stage/failed" ]; do
    sleep 0.5
    waited=$((waited + 1))
    if [ "$waited" -gt 360 ]; then
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
  rm -f "$out/screenshots"/*.png
  cp "$stage/out/screenshots/"*.png "$out/screenshots/"
  echo "showcase: $(find "$stage/out/screenshots" -name '*.png' | wc -l) screenshots in $out/screenshots"
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
