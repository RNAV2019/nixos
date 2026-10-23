#!/usr/bin/env bash
# Run dragpile in a throwaway nested Hyprland and screenshot scripted drags.
#
# The nested compositor is started by the live one on a hidden special workspace, so nothing
# appears on screen and focus never moves. Inside it, the only output is a headless one, which
# renders on its own clock whether or not the parent window is visible. The nested instance has
# no seat session (libseat is pointed at a seatd socket that does not exist) and is told not to
# touch the systemd/D-Bus activation environment, so it cannot disturb the live session.
#
# usage: run.sh <libdragpile.so> <scenario>...   (scenarios: see test/scenarios/*.txt)
# DRAGPILE_OPTS adds plugin options, e.g. DRAGPILE_OPTS="tab_drags = false".
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN=$(readlink -f "$1")
shift
OUT=${OUT:-/tmp/dragpile-test}
SCALE=${SCALE:-1.33}
mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/*.log "$OUT"/*.state
REPO=$(cd "$HERE/../../.." && pwd)
mkdir -p "$OUT/fixtures"
for f in bundle.zip handout.pdf song.flac clip.mp4 notes.txt; do echo fixture >"$OUT/fixtures/$f"; done

: "${HYPRLAND:?set HYPRLAND to the hyprland package the plugin was built against}"
: "${GRIM:?set GRIM to a grim package}"
: "${DRAGSRC:?set DRAGSRC to the built dragsrc binary}"

cat >"$OUT/nested.lua" <<EOF
hl.plugin.load("$PLUGIN")
hl.config({
  xwayland = { enabled = false },
  ecosystem = { no_update_news = true, no_donation_nag = true },
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, background_color = "rgb(0b2a24)" },
  input = { sensitivity = 0, accel_profile = "flat" },
  animations = { enabled = false },
  debug = { disable_logs = false },
  general = { gaps_out = 0, gaps_in = 0, border_size = 0 },
  plugin = { dragpile = { cursor = "default"${DRAGPILE_OPTS:+, $DRAGPILE_OPTS} } },
})
EOF

cat >"$OUT/launch.sh" <<EOF
#!/bin/sh
exec env -u NOTIFY_SOCKET -u HYPRLAND_INSTANCE_SIGNATURE HYPRLAND_NO_SD_VARS=1 LIBSEAT_BACKEND=seatd SEATD_SOCK=/nonexistent \\
  "$HYPRLAND/bin/Hyprland" -c "$OUT/nested.lua" >"$OUT/nested.log" 2>&1
EOF
chmod +x "$OUT/launch.sh"

LIVE=$HYPRLAND_INSTANCE_SIGNATURE
before=$(hyprctl instances -j | jq -r '.[].instance' | sort)
hyprctl dispatch "hl.dsp.exec_cmd('$OUT/launch.sh', { workspace = 'special:dragpile silent', no_initial_focus = true })" >/dev/null

NS=""
for _ in $(seq 100); do
  NS=$(comm -13 <(echo "$before") <(hyprctl instances -j | jq -r '.[].instance' | sort) | head -n1)
  [ -n "$NS" ] && break
  sleep 0.1
done
[ -n "$NS" ] || { echo "nested Hyprland did not start"; cat "$OUT/nested.log"; exit 1; }
[ "$NS" != "$LIVE" ] || { echo "refusing to drive the live instance"; exit 1; }
WS=$(hyprctl instances -j | jq -r --arg i "$NS" '.[] | select(.instance == $i) | .wl_socket')
NPID=$(hyprctl instances -j | jq -r --arg i "$NS" '.[] | select(.instance == $i) | .pid')
echo "nested: $NS on $WS (pid $NPID)"

nh() { hyprctl --instance "$NS" "$@"; }
cleanup() { kill "$NPID" 2>/dev/null || true; }
trap cleanup EXIT

sleep 1
nh output create headless DRAGPILE >/dev/null
nh eval "hl.monitor({ output = 'DRAGPILE', mode = '1280x800@60', position = '0x0', scale = $SCALE })" >/dev/null
nh eval "hl.monitor({ output = 'WAYLAND-1', disabled = true })" >/dev/null
sleep 0.5
nh plugin list | sed "s/^/  /"
nh monitors -j | jq -c ".[] | {name, disabled, x, y, width, height, scale}"

shoot() { WAYLAND_DISPLAY=$WS "$GRIM/bin/grim" -o DRAGPILE "$OUT/$1.png" 2>>"$OUT/grim.log" || true; }

for scenario in "$@"; do
  name=$(basename "$scenario" .txt)
  read -r flags <"$scenario.flags" 2>/dev/null || flags=""
  read -r shots <"$scenario.shots" 2>/dev/null || shots=""
  echo "== $name"
  WAYLAND_DISPLAY=$WS "$DRAGSRC" $flags --script "$scenario" $(sed "s|@REPO@|$REPO|g; s|@OUT@|$OUT|g" "$scenario.uris" | tr " " "\n" | sed "s|^|file://|") >"$OUT/$name.log" 2>&1 &
  pid=$!
  start=$(date +%s%3N)
  for at in $shots; do
    while [ $(($(date +%s%3N) - start)) -lt "$at" ]; do sleep 0.005; done
    shoot "$name-$at"
    nh dragpile >>"$OUT/$name.state" 2>/dev/null || true
    echo >>"$OUT/$name.state"
  done
  wait "$pid" || echo "dragsrc exited $?"
  sed 's/^/  /' "$OUT/$name.log"
done

grep -i "dragpile\|plugin" "$OUT/nested.log" | head -20 || true
