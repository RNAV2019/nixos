#!/usr/bin/env bash
# The clean-up's motion gate: checks a recording made with the two record.sh lines in
# ~/.cache/qs-verify/cleanup-motion-commands.txt and prints one line per failing
# scenario, label and rule, so two runs compare without their frame numbers. The first
# line says how many logs were read, so a run that checked nothing cannot pass as clean.
# Usage: cleanup-check.sh OUT_DIR   (OUT_DIR holds <scenario>.log)
set -u -o pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: cleanup-check.sh OUT_DIR}
split=$(mktemp -d)
trap 'rm -rf "$split"' EXIT
mkdir -p "$split/nl" "$split/lock"
count=0
for f in "$out"/*.log; do
  [[ -e $f ]] || continue
  count=$((count + 1))
  case $(basename "$f") in
    lock-*) cp "$f" "$split/lock/" ;;
    *) cp "$f" "$split/nl/" ;;
  esac
done
if ((count == 0)); then
  echo "cleanup-check: no .log files in $out" >&2
  exit 2
fi
echo "analysed $count logs"
for part in nl lock; do
  ls "$split/$part"/*.log >/dev/null 2>&1 || continue
  nix run nixpkgs#nodejs -- "$here/check.mjs" "$split/$part" \
    --expect "$here/expect-handover.txt" \
    --expect-static 'surface.*.contentX' \
    --expect-monotonic 'surface.*.body' \
    --expect-fade-frames 'surface.*.body:3' \
    --expect-continuity 'surface.*.w,surface.*.h' \
    --overshoot-tol 'lock.pill.w:2,dict.bar*:0.25' >"$split/$part.out" 2>&1
  status=$?
  # check.mjs exits 0 when clean and 1 when a rule failed; anything else did not check.
  if ((status > 1)); then
    echo "cleanup-check: check.mjs exited $status on the $part logs" >&2
    cat "$split/$part.out" >&2
    exit 2
  fi
  grep -E ': [A-Za-z0-9_-]+ at frame ' "$split/$part.out" | sed -E 's/ at frame.*//; s|^.*/||' || true
done | sort -u
