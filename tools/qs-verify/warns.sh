#!/usr/bin/env bash
# The warnings in a quickshell log, as distinct messages with pointers and line numbers taken
# out. With a second file (a list this printed for a known-good run) it prints the messages
# that are new and fails when there are any: counts drift from run to run, kinds do not.
set -u -o pipefail
log=${1:?usage: warns.sh QUICKSHELL_LOG [KNOWN_LIST]}
[[ -r $log ]] || {
  echo "warns: cannot read $log" >&2
  exit 2
}
kinds=$(grep WARN "$log" | sed -E 's/0x[0-9a-f]+/PTR/g; s/\[[0-9]+:-?[0-9]+\]/[L]/g; s/^[^W]*WARN/WARN/' | sort -u || true)
if (($# < 2)); then
  printf '%s\n' "$kinds"
  exit 0
fi
[[ -r $2 ]] || {
  echo "warns: cannot read $2" >&2
  exit 2
}
new=$(comm -23 <(printf '%s\n' "$kinds") <(sort -u "$2"))
if [[ -n $new ]]; then
  echo "warns: new kinds of warning:"
  printf '%s\n' "$new"
  exit 1
fi
echo "warns: no new kind of warning"
