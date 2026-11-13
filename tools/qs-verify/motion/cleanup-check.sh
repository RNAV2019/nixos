#!/usr/bin/env bash
# The clean-up's motion gate: checks a recording made with the two record.sh lines in
# ~/.cache/qs-verify/cleanup-motion-commands.txt and prints one line per failing
# scenario, label and rule, so two runs compare without their frame numbers.
# Usage: cleanup-check.sh OUT_DIR   (OUT_DIR holds <scenario>.log)
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: cleanup-check.sh OUT_DIR}
split=$(mktemp -d)
trap 'rm -rf "$split"' EXIT
mkdir -p "$split/nl" "$split/lock"
for f in "$out"/*.log; do
  case $(basename "$f") in
    lock-*) cp "$f" "$split/lock/" ;;
    *) cp "$f" "$split/nl/" ;;
  esac
done
for part in nl lock; do
  ls "$split/$part"/*.log >/dev/null 2>&1 || continue
  nix run nixpkgs#nodejs -- "$here/check.mjs" "$split/$part" \
    --expect "$here/expect-handover.txt" \
    --expect-static 'surface.*.contentX' \
    --expect-monotonic 'surface.*.body' \
    --expect-fade-frames 'surface.*.body:3' \
    --expect-continuity 'surface.*.w,surface.*.h' \
    --overshoot-tol 'lock.pill.w:2,dict.bar*:0.25' 2>&1
done | grep -E ': [a-z-]+ at frame ' | sed -E 's/ at frame.*//; s|^.*/||' | sort -u
