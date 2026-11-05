#!/usr/bin/env bash
# record.sh TREE OUT_DIR SCENARIO...
#
# Starts the qs-verify harness on TREE (a quickshell config dir) at 120 Hz with the shell's motion
# log on (QS_REFRESH=120, QS_MOTION_LOG=1, theme ariadne), runs each scenario from scenarios.sh and
# writes, per scenario:
#   OUT_DIR/<scenario>.log   the quickshell log lines "motion <label> <t_ms> <value> <velocity> <target>"
#   OUT_DIR/<scenario>.mkv   with QS_VIDEO=1: a lossless 120 fps capture of the output (wf-recorder)
# The scenario `reduce` restarts the harness with QUICKSHELL_REDUCE_MOTION=1 and runs every
# scenario into OUT_DIR/reduce/ (check with: check.mjs OUT_DIR/reduce --max-anim-ms 80).
# `all` stands for every scenario. The harness is torn down at the end (QS_KEEP=1 leaves it up).
# QS_VERIFY_WORK picks the work dir (default /tmp/qsv-motion). Never touches the live session.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QSV=$(cd "$HERE/.." && pwd)
REAL_HOME=$HOME
# shellcheck source=../lib.sh
source "$QSV/lib.sh"
export QS_VERIFY_WORK=${QS_VERIFY_WORK:-/tmp/qsv-motion}
QSV_WORK=$QS_VERIFY_WORK
QSV_ENV=$QSV_WORK/env.sh

[[ $# -ge 3 ]] || die "usage: record.sh TREE OUT_DIR SCENARIO..."
TREE=$(cd "$1" && pwd)
mkdir -p "$2"
OUT=$(cd "$2" && pwd)
shift 2
# shellcheck source=scenarios.sh
source "$HERE/scenarios.sh"

NAMES=()
for n in "$@"; do
  if [[ $n == all ]]; then read -ra NAMES <<<"$SCENARIOS reduce"; else NAMES+=("$n"); fi
done
for n in "${NAMES[@]}"; do
  [[ $n == reduce ]] || declare -F "sc_${n//-/_}" >/dev/null || die "no scenario '$n' (have: $SCENARIOS reduce)"
done

if [[ ${QS_VIDEO:-} == 1 ]]; then
  VP=$(nix build --inputs-from "$QSV_REPO" --no-link --print-out-paths nixpkgs#wf-recorder | head -n1)
  [[ -x $VP/bin/wf-recorder ]] || die "no wf-recorder"
  WFREC=$VP/bin/wf-recorder
fi

start_harness() { # [ENV=VALUE...]
  env -u XDG_RUNTIME_DIR "$QSV/stop.sh" >/dev/null 2>&1 || true
  env HOME=$REAL_HOME QS_THEME=ariadne QS_REFRESH=120 QS_MOTION_LOG=1 "$@" "$QSV/run.sh" "$TREE" >"$QSV_WORK.run.log" 2>&1 \
    || { cat "$QSV_WORK.run.log" >&2; die "run.sh failed"; }
  load_env
  PH_CALLS=$QSV_WORK/phone-calls.log
  PH_STORAGE=$QSV_WORK/phone-storage
  NB_SEND=$HOME/send-fixtures
  local hz
  hz=$(swaymsg -t get_outputs | grep -o '"refresh": *[0-9]*' | head -n1 | grep -o '[0-9]*$')
  echo "record: output refresh ${hz:-?} mHz"
  [[ ${hz:-0} -ge 119000 ]] || echo "record: WARNING the output is not at 120 Hz" >&2
}

# One scenario into DIR: reset, mark the log, (record), run, cut the motion lines.
run_one() { # DIR NAME
  local dir=$1 name=$2 log=$QSV_WORK/quickshell.log mark rec=
  mkdir -p "$dir"
  reset_ui
  mark=$(stat -c %s "$log")
  if [[ -n ${WFREC:-} ]]; then
    "$WFREC" -D -r 120 -c libx264rgb -p preset=ultrafast -p crf=0 -f "$dir/$name.mkv" >"$QSV_WORK/wf-recorder.log" 2>&1 &
    rec=$!
    sleep 1.0
  fi
  "sc_${name//-/_}"
  sleep 0.3
  if [[ -n $rec ]]; then
    kill -INT "$rec" 2>/dev/null || true
    wait "$rec" 2>/dev/null || true
  fi
  tail -c +"$((mark + 1))" "$log" \
    | sed -nE 's/^(.*[^[:alnum:]_.])?(motion [^ ]+ [-0-9.eE+]+ [-0-9.eE+]+ [-0-9.eE+]+ [-0-9.eE+]+)[[:space:]]*$/\2/p' >"$dir/$name.log"
  echo "record: $name: $(wc -l <"$dir/$name.log") motion lines${rec:+, video}"
}

normal=()
want_reduce=0
for n in "${NAMES[@]}"; do
  if [[ $n == reduce ]]; then want_reduce=1; else normal+=("$n"); fi
done

if ((${#normal[@]})); then
  start_harness
  for n in "${normal[@]}"; do run_one "$OUT" "$n"; done
fi
if ((want_reduce)); then
  start_harness QUICKSHELL_REDUCE_MOTION=1
  for n in $SCENARIOS; do run_one "$OUT/reduce" "$n"; done
fi
[[ ${QS_KEEP:-} == 1 ]] || env -u XDG_RUNTIME_DIR "$QSV/stop.sh" >/dev/null || env -u XDG_RUNTIME_DIR "$QSV/stop.sh" >/dev/null || echo "record: WARNING the harness did not stop cleanly" >&2
echo "record: done -> $OUT"
