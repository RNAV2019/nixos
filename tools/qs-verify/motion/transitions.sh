#!/usr/bin/env bash
# transitions.sh OUT_DIR [A:B ...]
#
# Records surface-to-surface transitions for review, on a harness that is already up (run.sh,
# QS_REFRESH=120 recommended). For each A:B it opens A, lets it settle, starts a lossless 120 fps
# capture, opens B over it, and stops the capture once B has settled: OUT_DIR/A-B.mkv. With no
# pairs, every ordered pair of PANELS. A side may be a transient as well as a panel:
#   osd-volume osd-brightness toast rebuild moment-plugged
# sheet.py then cuts each capture into a contact sheet.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QSV=$(cd "$HERE/.." && pwd)
# shellcheck source=../lib.sh
source "$QSV/lib.sh"
QSV_WORK=${QS_VERIFY_WORK:-/tmp/qs-verify-$USER}
QSV_ENV=$QSV_WORK/env.sh
load_env
PH_CALLS=$QSV_WORK/phone-calls.log
PH_STORAGE=$QSV_WORK/phone-storage
NB_SEND=$HOME/send-fixtures
[[ ${XDG_RUNTIME_DIR:-} == /tmp/* ]] || die "refusing to record: XDG_RUNTIME_DIR is not the harness's"

[[ $# -ge 1 ]] || die "usage: transitions.sh OUT_DIR [A:B ...]"
mkdir -p "$1"
OUT=$(cd "$1" && pwd)
shift

PANELS=${PANELS:-"launcher control calendar session profiles recorder theme wallpaper nearby phone"}
PAIRS=("$@")
if ((${#PAIRS[@]} == 0)); then
  for a in $PANELS; do
    for b in $PANELS; do
      [[ $a == "$b" ]] || PAIRS+=("$a:$b")
    done
  done
fi

VP=$(nix build --inputs-from "$QSV_REPO" --no-link --print-out-paths nixpkgs#wf-recorder | head -n1)
WFREC=$VP/bin/wf-recorder

wpctl() { command wpctl "$@" 2>/dev/null; }
PHONE_UP=0

# Closes what the last pair raised (every panel with no argument), and clears the transients.
reset_all() {
  local k keys=${1:-launcher control wallpaper profiles calendar nearby recorder theme phone session}
  for k in $keys; do
    case $k in
      osd-* | toast | close-* | dictation* | sharing | rebuild | moment-next) ;;
      moment-*) qsipc activities dismissMoments >/dev/null 2>&1 || true ;;
      *) qsipc "$k" close >/dev/null 2>&1 || true ;;
    esac
  done
  # Transients from the pair before: every one is cleared, whatever the pair named.
  qsipc activities dismissMoments >/dev/null 2>&1 || true
  qsipc activities wifi full "" >/dev/null 2>&1 || true
  printf '%s\n' '{"event":"hide"}' >>"$DICT" 2>/dev/null || true
  printf '%s\n' "{\"event\":\"transfer\",\"transfer\":{\"id\":\"${NB_ID:-qs:192.168.1.20:41234}\",\"protocol\":\"quickshare\",\"direction\":\"in\",\"state\":\"cancelled\",\"peer\":\"Galaxy S24\",\"pin\":\"4821\",\"kind\":\"files\",\"files\":[\"IMG_0001.jpg\"],\"text\":null,\"saved_paths\":[],\"total_bytes\":2400000,\"bytes\":0,\"error\":null,\"started\":0}}" >>"$NB" 2>/dev/null || true
  printf '%s\n' '{"event":"transfers_cleared"}' >>"$NB" 2>/dev/null || true
  [[ -z $rb_pid ]] || { kill "$rb_pid" 2>/dev/null; rb_pid=; sleep 13; }
  cursor 200 900
  sleep 1.4
}

DICT=$QSV_WORK/dictation.events
NB=$QSV_WORK/nearby.events
RB_LOG=$XDG_RUNTIME_DIR/rebuild.jsonl
rb_pid=
rb_id() { echo $((rb_pid * 4294967296 + $1)); }
rb_emit() { printf '%s\n' "$1" >>"$RB_LOG"; }

# Brings one side up: a panel by its key, or a transient by name.
raise() {
  case $1 in
    dictation) printf '%s\n' '{"event":"state","state":"recording"}' >>"$DICT" ;;
    dictation-off) printf '%s\n' '{"event":"hide"}' >>"$DICT" ;;
    sharing)
      NB_ID="qs:192.168.1.20:$((40000 + RANDOM % 20000))"
      printf '%s\n' "{\"event\":\"transfer\",\"transfer\":{\"id\":\"$NB_ID\",\"protocol\":\"quickshare\",\"direction\":\"in\",\"state\":\"connecting\",\"peer\":\"Galaxy S24\",\"pin\":\"4821\",\"kind\":\"files\",\"files\":[\"IMG_0001.jpg\"],\"text\":null,\"saved_paths\":[],\"total_bytes\":2400000,\"bytes\":0,\"error\":null,\"started\":$(date +%s)}}" >>"$NB" ;;
    rebuild)
      : >"$RB_LOG"
      sleep 1.3
      setsid sleep 600 >/dev/null 2>&1 &
      rb_pid=$!
      rb_emit "{\"action\":\"start\",\"id\":$(rb_id 1),\"level\":3,\"type\":0,\"text\":\"evaluating\",\"fields\":[]}"
      ;;
    moment-wifi) qsipc activities wifi portal "Campus WiFi" >/dev/null ;;
    moment-next) qsipc activities next >/dev/null ;;
    close-*) qsipc "${1#close-}" close >/dev/null ;;
    osd-volume)
      wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
      # One change: two would show the first level and then the second.
      # Never the level it is at already: no change, no OSD.
      VOL_STEP=$(((${VOL_STEP:-0} + 13) % 55))
      wpctl set-volume @DEFAULT_AUDIO_SINK@ "0.$((35 + VOL_STEP))"
      ;;
    osd-brightness)
      # The shell watches the fake backlight; two writes, the second the one shown.
      echo $((600 + RANDOM % 200)) >"$QSV_WORK/fake/backlight/panel/brightness"
      ;;
    toast) env -u LD_LIBRARY_PATH notify-send -t 1500 -a Mail "Lena Ortiz" "Draft for Monday is in the shared folder" ;;
    moment-plugged) qsipc activities plug $((40 + RANDOM % 50)) $((20 + RANDOM % 90)) >/dev/null ;;
    phone)
      if ((!PHONE_UP)); then
        ph_up
        PHONE_UP=1
        sleep 1.0
      fi
      qsipc phone toggle >/dev/null
      ;;
    *) qsipc "$1" toggle >/dev/null ;;
  esac
}

# Every panel opened once first, so no capture pays a cold window (Ui/IslandSurfaceBase.qml parks
# windows; a first open builds one and waits out its first frame).
for k in $PANELS; do
  raise "$k"
  sleep 0.9
  qsipc "$k" close >/dev/null 2>&1 || true
  sleep 0.6
done

# A pair is A:B[:SECONDS]; either side may be several steps, comma-separated (toast,close-control:
# a toast queued behind a panel, then the panel closed). SECONDS is how long B is recorded for.
for pair in "${PAIRS[@]}"; do
  IFS=: read -r a b hold <<<"$pair"
  hold=${hold:-0.9}
  name="${a//,/+}-${b//,/+}"
  reset_all "${prev:-}"
  # The pair once unrecorded first (QS_WARM=0 skips it): the clip shader's blur, with a morph's mask
  # bound, is another variant for the driver to build the first time each window draws it, and the
  # headless renderer builds it in the frame (100 ms and more), which a capture would show as a
  # freeze the live shell only has once after a driver update.
  if [[ ${QS_WARM:-1} == 1 ]]; then
    for s in ${a//,/ }; do raise "$s"; sleep 0.15; done
    sleep 0.8
    for s in ${b//,/ }; do raise "$s"; sleep 0.6; done
    sleep 0.6
    reset_all "${a//,/ } ${b//,/ }"
  fi
  prev="${a//,/ } ${b//,/ }"
  case ${a%%,*} in
    osd-* | toast | moment-* | dictation | sharing | rebuild)
      # A transient expires: the capture starts first and A comes up inside it (sheet.py finds the
      # transition after A has settled).
      "$WFREC" -y -D -c libx264rgb -p preset=ultrafast -p crf=0 -f "$OUT/$name.mkv" >"$QSV_WORK/wf-recorder.log" 2>&1 &
      rec=$!
      sleep 1.0
      for s in ${a//,/ }; do raise "$s"; sleep 0.15; done
      sleep 0.55
      ;;
    *)
      for s in ${a//,/ }; do raise "$s"; sleep 0.15; done
      sleep 1.1
      "$WFREC" -y -D -c libx264rgb -p preset=ultrafast -p crf=0 -f "$OUT/$name.mkv" >"$QSV_WORK/wf-recorder.log" 2>&1 &
      rec=$!
      sleep 0.7
      ;;
  esac
  # Steps of B one after another, each given time to take effect (a queued pill must be in the
  # queue before the panel in front of it closes); the mark is the last one, the handover.
  read -ra steps <<<"${b//,/ }"
  for ((k = 0; k < ${#steps[@]} - 1; k++)); do
    raise "${steps[k]}"
    sleep 0.6
  done
  date +%s%3N >"$OUT/$name.mark"
  raise "${steps[-1]}"
  sleep "$hold"
  date +%s%3N >"$OUT/$name.stop"
  kill -INT "$rec" 2>/dev/null || true
  wait "$rec" 2>/dev/null || true
  grep -a "morph pairs" "$QSV_WORK/quickshell.log" | tail -n1 >"$OUT/$name.pairs" || true
  echo "transitions: $name"
done
reset_all
echo "transitions: done -> $OUT"
