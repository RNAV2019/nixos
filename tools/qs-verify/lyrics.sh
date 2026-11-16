#!/usr/bin/env bash
# The lyric pill (home/quickshell/Lyrics, Bar/Island.qml) on the headless harness: bring it up
# with the mock player and the fixture song, and take the island at chosen moments of the song.
# The words are drawn from the song's time alone, so the pill at 38.2 s is the same picture every
# run, and a row of frames a fortieth of a second apart is the motion itself.
#
#   lyrics.sh up                    the harness, the player and the song
#   lyrics.sh sync                  copy the tree's config over the harness's and restart the shell
#   lyrics.sh frames OUT T...       OUT/T.png, the island with the song held at each T (seconds)
#   lyrics.sh strip OUT FROM TO N   N frames from FROM to TO stacked as one sheet, OUT/FROM-TO.png
#   lyrics.sh play OUT FROM SECS    let the song run from FROM and take the island every 100 ms
#   lyrics.sh log                   what the shell has warned of since the last sync
#   lyrics.sh down                  tear it all down
#
# QS_VERIFY_WORK picks the harness (default /tmp/qsv-lyrics): give each tree at work its own.
# QS_SCALE and QS_THEME are run.sh's. The song is fixtures/lyrics-plus.json (25 lines: verse
# from 8 s, pre-chorus 27.2, chorus 36.8, a pause from 56.5, verse 64, chorus 83.2, bridge 102.4,
# chorus 116.8). A held song moves the shape by its spring, in the wall's time: `frames` waits
# QS_SETTLE (0.9 s) for it, and `strip` only as long as it is told (0.25 s), so a strip across a
# change of line shows the words exactly and the pill's width wherever it had got to.
set -euo pipefail
export QS_VERIFY_WORK=${QS_VERIFY_WORK:-/tmp/qsv-lyrics}
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"
cmd=${1:-}
shift || true

# The top middle of the output, where the island is: wide enough for the widest line, tall
# enough for the pill and its shadow. In the output's own coordinates, which the scale divides.
island() {
  local x
  x=$(awk -v s="$QSV_SCALE" 'BEGIN { printf "%d", 1920 / s / 2 - 400 }')
  grim -g "$x,0 800x76" "$1"
}

case $cmd in
  up)
    "$here/stop.sh" >/dev/null 2>&1 || true
    QS_THEME=${QS_THEME:-ariadne} "$here/run.sh" "$QSV_REPO/home/quickshell" >/dev/null
    load_env
    cp "$here/fixtures/lyrics-plus.json" "$QSV_WORK/lyrics-plus.json"
    : >"$QSV_WORK/quickshell.log"
    "$here/restart.sh" >/dev/null
    media_up
    echo "lyrics: up (work $QSV_WORK)"
    ;;
  sync)
    load_env
    for d in Bar Lyrics Services Ui; do
      rm -rf "${QSV_CFG:?}/$d"
      cp -r "$QSV_REPO/home/quickshell/$d" "$QSV_CFG/$d"
    done
    cp "$QSV_REPO/home/quickshell/shell.qml" "$QSV_CFG/shell.qml"
    # Theme carries run.sh's OLED patch: make it again on the fresh copy.
    sed -E 's/(readonly property int oledShiftInterval: )[0-9]+/\12000000000/' \
      "$QSV_REPO/home/quickshell/Commons/Theme.qml" >"$QSV_CFG/Commons/Theme.qml"
    : >"$QSV_WORK/quickshell.log"
    "$here/restart.sh" >/dev/null
    ;;
  frames)
    load_env
    out=$1
    shift
    mkdir -p "$out"
    media_up
    for t in "$@"; do
      qsipc lyrics pin "$t"
      sleep "${QS_SETTLE:-0.9}"
      island "$out/$t.png"
    done
    ;;
  strip)
    load_env
    out=$1 from=$2 to=$3 n=$4
    mkdir -p "$out"
    tmp=$(mktemp -d)
    media_up
    qsipc lyrics pin "$from"
    sleep 0.9
    for i in $(seq 0 $((n - 1))); do
      t=$(awk -v a="$from" -v b="$to" -v i="$i" -v n="$n" 'BEGIN { printf "%.3f", a + (b - a) * i / (n - 1) }')
      qsipc lyrics pin "$t"
      sleep "${QS_SETTLE:-0.25}"
      island "$tmp/$(printf %03d "$i").png"
    done
    need_magick
    magick "$tmp"/*.png -append "$out/$from-$to.png"
    rm -rf "$tmp"
    echo "$out/$from-$to.png"
    ;;
  play)
    load_env
    out=$1 from=$2 secs=$3
    mkdir -p "$out"
    tmp=$(mktemp -d)
    media_up
    qsipc lyrics pin -1
    mp SetPosition ox /org/qsv/track/0 "$(awk -v t="$from" 'BEGIN { printf "%d", t * 1000000 }')"
    n=$(awk -v s="$secs" 'BEGIN { printf "%d", s * 10 }')
    for i in $(seq 0 $((n - 1))); do
      island "$tmp/$(printf %03d "$i").png"
      sleep 0.07
    done
    need_magick
    magick "$tmp"/*.png -append "$out/play-$from.png"
    rm -rf "$tmp"
    echo "$out/play-$from.png"
    ;;
  log)
    load_env
    grep -E "WARN|ERROR" "$QSV_WORK/quickshell.log" | sort | uniq -c | sort -rn | head -30 || true
    crashes=$({ find "$XDG_CACHE_HOME/quickshell/crashes" -mindepth 1 -maxdepth 1 2>/dev/null || true; } | wc -l)
    if ((crashes > 0)); then
      echo "$crashes crash report(s) in $XDG_CACHE_HOME/quickshell/crashes"
    fi
    ;;
  down)
    "$here/stop.sh"
    ;;
  *)
    sed -n '2,20p' "$0"
    exit 2
    ;;
esac
