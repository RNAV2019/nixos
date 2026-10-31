#!/usr/bin/env bash
# stop.sh — tear the harness down: everything it started carries the scratch XDG_RUNTIME_DIR in
# its environment, so find those processes by that rather than trusting pid files. Does not
# source the harness env (it would match itself) and never touches anything else.
set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

rt=$QSV_WORK/rt

# Our own ancestors must survive (a script that sourced the env is a legitimate caller).
protected=" $$ "
p=$PPID
while [[ $p -gt 1 ]]; do
  protected+="$p "
  p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null || echo 1)
done

harness_pids() {
  local f pid
  for f in /proc/[0-9]*/environ; do
    pid=${f#/proc/}
    pid=${pid%/environ}
    [[ $protected == *" $pid "* ]] && continue
    if { tr "\0" "\n" <"$f" | grep -qxF "XDG_RUNTIME_DIR=$rt"; } 2>/dev/null; then
      echo "$pid"
    fi
  done
}

for sig in TERM KILL; do
  mapfile -t pids < <(harness_pids)
  [[ ${#pids[@]} -eq 0 ]] && break
  kill -"$sig" "${pids[@]}" 2>/dev/null
  for _ in $(seq 30); do
    mapfile -t pids < <(harness_pids)
    [[ ${#pids[@]} -eq 0 ]] && break 2
    sleep 0.1
  done
done

mapfile -t left < <(harness_pids)
if [[ ${#left[@]} -gt 0 ]]; then
  echo "qs-verify: could not stop pids: ${left[*]}" >&2
  exit 1
fi
rm -rf "$QSV_WORK"
echo "qs-verify: stopped"
