#!/usr/bin/env bash
# Run the scripted drags against the live Hyprland, on an empty workspace. The plugin must
# already be loaded (hyprctl plugin load …). Screenshots come from grim, which leaves the
# hardware cursor out, so the pointer itself does not show.
#
# usage: run-live.sh <scenario>...
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/tmp/dragpile-live}
OUTPUT=${OUTPUT:-eDP-1}
WORKSPACE=${WORKSPACE:-6}
mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/*.log "$OUT"/*.state
REPO=$(cd "$HERE/../../.." && pwd)
mkdir -p "$OUT/fixtures"
for f in bundle.zip handout.pdf song.flac clip.mp4 notes.txt; do echo fixture >"$OUT/fixtures/$f"; done

: "${GRIM:?set GRIM to a grim package}"
: "${DRAGSRC:?set DRAGSRC to the built dragsrc binary}"

hyprctl plugin list | grep -q dragpile || { echo "dragpile is not loaded"; exit 1; }

before=$(hyprctl activeworkspace -j | jq -r .id)
hyprctl dispatch "hl.dsp.focus({ workspace = $WORKSPACE })" >/dev/null
trap 'hyprctl dispatch "hl.dsp.focus({ workspace = $before })" >/dev/null' EXIT

# Centre of the output, in layout coordinates.
read -r cx cy < <(hyprctl monitors -j | jq -r --arg o "$OUTPUT" '.[] | select(.name == $o) | "\(.x + (.width / .scale / 2 | floor)) \(.y + (.height / .scale / 2 | floor))"')

shoot() { "$GRIM/bin/grim" -o "$OUTPUT" "$OUT/$1.png" 2>>"$OUT/grim.log" || true; }

for scenario in "$@"; do
  name=$(basename "$scenario" .txt)
  read -r flags <"$scenario.flags" 2>/dev/null || flags=""
  read -r shots <"$scenario.shots" 2>/dev/null || shots=""
  read -r startAt <"$scenario.start" 2>/dev/null || startAt="0 0"
  read -r ox oy <<<"$startAt"
  hyprctl dispatch "hl.dsp.cursor.move({ x = $((cx + ox)), y = $((cy + oy)), absolute = true })" >/dev/null
  echo "== $name"
  "$DRAGSRC" $flags --script "$scenario" $(sed "s|@REPO@|$REPO|g; s|@OUT@|$OUT|g" "$scenario.uris" | tr " " "\n" | sed "s|^|file://|") >"$OUT/$name.log" 2>&1 &
  pid=$!
  start=$(date +%s%3N)
  for at in $shots; do
    while [ $(($(date +%s%3N) - start)) -lt "$at" ]; do sleep 0.005; done
    shoot "$name-$at"
    { hyprctl dragpile; echo; } >>"$OUT/$name.state" 2>/dev/null || true
  done
  wait "$pid" || echo "dragsrc exited $?"
  sed 's/^/  /' "$OUT/$name.log"
  sleep 0.5
done
