#!/usr/bin/env bash
# The lyric stage (home/quickshell/Lyrics) on the headless harness: bring it up with the mock
# player and the fixture song, and take frames at chosen moments of the song. Every style draws
# from the song's time alone, so a frame at 38.2 s is the same picture every run, and a row of
# frames a fortieth of a second apart is the motion itself.
#
#   lyrics.sh up                          the harness, the lyric faces, the player and the song
#   lyrics.sh sync                        copy the tree's lyric files over the harness's and restart the shell
#   lyrics.sh frames OUT STYLE T...       OUT/STYLE-T.png for each time T (seconds); STYLE "" casts by section
#   lyrics.sh strip OUT STYLE FROM TO N   N frames from FROM to TO as one sheet, OUT/STYLE-FROM-TO.png
#   lyrics.sh log                         what the shell has warned of since the last sync
#   lyrics.sh down                        tear it all down
#
# QS_VERIFY_WORK picks the harness (default /tmp/qsv-lyrics): give each tree at work its own.
# QS_SCALE and QS_THEME are run.sh's. The song is fixtures/lyrics-plus.json (25 lines: verse
# from 8 s, pre-chorus 27.2, chorus 36.8, a pause, verse 64, chorus 83.2, bridge 102.4, chorus
# 116.8); `rm $QS_VERIFY_WORK/lyrics-plus.json` and a restart show the stage with no lyrics.
set -euo pipefail
export QS_VERIFY_WORK=${QS_VERIFY_WORK:-/tmp/qsv-lyrics}
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"
cmd=${1:-}
shift || true

# A shell that crashed is started again by Quickshell itself, with the files it had, outside the
# pid file: put any such copy down, or it goes on answering in place of the one about to start.
strays() {
  local p
  for p in $(pgrep -x .quickshell-wra 2>/dev/null); do
    # (Another session's shell is not ours to read, and says so: that is not an error.)
    if { tr '\0' '\n' <"/proc/$p/environ"; } 2>/dev/null | grep -qx "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"; then
      kill "$p" 2>/dev/null || true
    fi
  done
}

open_stage() {
  media_up
  [[ $(qsipc lyrics shown) == true ]] && return 0
  qsipc lyrics toggle
  sleep 2.2
}

case $cmd in
  up)
    "$here/stop.sh" >/dev/null 2>&1 || true
    QS_THEME=${QS_THEME:-ariadne} "$here/run.sh" "$QSV_REPO/home/quickshell" >/dev/null
    load_env
    fonts=$(nix build --no-link --print-out-paths --impure --expr \
      "let f = builtins.getFlake \"$QSV_REPO\"; in (import f.inputs.nixpkgs { system = \"x86_64-linux\"; overlays = [ f.overlays.default ]; }).lyric-fonts")
    mkdir -p "$HOME/.local/share/fonts"
    cp "$fonts"/share/fonts/truetype/*.ttf "$HOME/.local/share/fonts/"
    cp "$here/fixtures/lyrics-plus.json" "$QSV_WORK/lyrics-plus.json"
    : >"$QSV_WORK/quickshell.log"
    "$here/restart.sh" >/dev/null
    media_up
    echo "lyrics: up (work $QSV_WORK)"
    ;;
  sync)
    load_env
    rm -rf "$QSV_CFG/Lyrics"
    cp -r "$QSV_REPO/home/quickshell/Lyrics" "$QSV_CFG/Lyrics"
    cp "$QSV_REPO"/home/quickshell/Shaders/lyric* "$QSV_CFG/Shaders/"
    cp "$QSV_REPO/home/quickshell/Services/Lyrics.qml" "$QSV_CFG/Services/"
    cp "$QSV_REPO/home/quickshell/Commons/Paths.qml" "$QSV_CFG/Commons/"
    cp "$QSV_REPO/home/quickshell/shell.qml" "$QSV_CFG/shell.qml"
    # Theme carries run.sh's OLED patch: make it again on the fresh copy.
    sed -E 's/(readonly property int oledShiftInterval: )[0-9]+/\12000000000/' \
      "$QSV_REPO/home/quickshell/Commons/Theme.qml" >"$QSV_CFG/Commons/Theme.qml"
    : >"$QSV_WORK/quickshell.log"
    strays
    "$here/restart.sh" >/dev/null
    ;;
  frames)
    load_env
    out=$1 style=$2
    shift 2
    mkdir -p "$out"
    qsipc lyrics style "$style"
    qsipc lyrics pin "$1"
    open_stage
    for t in "$@"; do
      qsipc lyrics pin "$t"
      sleep "${QS_SETTLE:-0.9}"
      grim -o HEADLESS-1 "$out/${style:-cast}-$t.png"
    done
    ;;
  strip)
    load_env
    out=$1 style=$2 from=$3 to=$4 n=$5
    mkdir -p "$out"
    tmp=$(mktemp -d)
    qsipc lyrics style "$style"
    qsipc lyrics pin "$from"
    open_stage
    for i in $(seq 0 $((n - 1))); do
      t=$(awk -v a="$from" -v b="$to" -v i="$i" -v n="$n" 'BEGIN { printf "%.3f", a + (b - a) * i / (n - 1) }')
      qsipc lyrics pin "$t"
      sleep "${QS_SETTLE:-0.35}"
      grim -o HEADLESS-1 "$tmp/$(printf %03d "$i").png"
    done
    cols=$((n <= 4 ? n : n <= 12 ? 4 : 6))
    need_magick
    magick montage "$tmp"/*.png -resize 640x -tile "${cols}x" -geometry +4+4 -background '#202020' \
      "$out/${style:-cast}-$from-$to.png"
    rm -rf "$tmp"
    echo "$out/${style:-cast}-$from-$to.png"
    ;;
  log)
    load_env
    grep -E "WARN|ERROR" "$QSV_WORK/quickshell.log" | grep -E "Lyrics|lyric" | sort | uniq -c | sort -rn | head -30 || true
    crashes=$(find "$XDG_CACHE_HOME/quickshell/crashes" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    if ((crashes > 0)); then
      echo "$crashes crash report(s) in $XDG_CACHE_HOME/quickshell/crashes"
    fi
    ;;
  down)
    "$here/stop.sh"
    ;;
  *)
    sed -n '2,16p' "$0"
    exit 2
    ;;
esac
