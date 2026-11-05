#!/usr/bin/env bash
# media-cpu.sh TREE OUT_DIR [SECONDS]
#
# The control centre open with a mock MPRIS player playing (tools/qs-verify/mock-mpris.py): saves a
# still of the media card (OUT_DIR/media-card.png) and prints the shell's CPU time (utime+stime from
# /proc, in jiffies) over SECONDS (default 10) of that. QSG_RENDER_TIMING is too coarse here (swap
# dominated); compare the jiffies of two trees run in the same conditions. QS_VERIFY_WORK picks the
# work dir (default /tmp/qsv-media).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QSV=$(cd "$HERE/.." && pwd)
REAL_HOME=$HOME
source "$QSV/lib.sh"
export QS_VERIFY_WORK=${QS_VERIFY_WORK:-/tmp/qsv-media}
QSV_WORK=$QS_VERIFY_WORK
QSV_ENV=$QSV_WORK/env.sh
[[ $# -ge 2 ]] || die "usage: media-cpu.sh TREE OUT_DIR [SECONDS]"
TREE=$(cd "$1" && pwd)
mkdir -p "$2"
OUT=$(cd "$2" && pwd)
SECS=${3:-10}

env -u XDG_RUNTIME_DIR "$QSV/stop.sh" >/dev/null 2>&1 || true
env HOME=$REAL_HOME QS_THEME=ariadne "$QSV/run.sh" "$TREE" >"$QSV_WORK.run.log" 2>&1 \
  || { cat "$QSV_WORK.run.log" >&2; die "run.sh failed"; }
load_env
mpris_up Playing
sleep 1
qsipc control toggle >/dev/null
sleep 3
grim "$OUT/media-card.png"
pid=$(pgrep -u "$USER" -f "^quickshell --no-color -p $QSV_WORK/" | head -n1)
cpu() { awk '{print $14+$15}' "/proc/$pid/stat"; }
a=$(cpu)
sleep "$SECS"
b=$(cpu)
echo "media-cpu: pid $pid, $((b - a)) jiffies over ${SECS}s"
grim "$OUT/media-card-later.png"
env -u XDG_RUNTIME_DIR "$QSV/stop.sh" >/dev/null || true
