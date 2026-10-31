#!/usr/bin/env bash
# compare.sh BASE_DIR NEW_DIR [ALLOW_FILE] — compare two shoot.sh outputs, file by file.
#
# `magick compare -metric AE -fuzz 3%` after painting masks.txt's regions (the clock, rings and
# spinners) over both sides. A differing file leaves a diff image in NEW_DIR/diff/. Exits non-zero
# when a file differs and ALLOW_FILE (one capture name per line, # comments) does not list it, when
# a file exists on one side only, or when the two runs were not the same scenario (scale, theme).
# Captures that show today's date (date-dependent.txt) are skipped, loudly, when the two runs were
# made on different days.
set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need_magick
[[ $# -ge 2 && $# -le 3 ]] || die "usage: compare.sh BASE_DIR NEW_DIR [ALLOW_FILE]"
BASE=$(cd "$1" && pwd) || die "no such directory: $1"
NEW=$(cd "$2" && pwd) || die "no such directory: $2"
ALLOW=${3:-}
[[ -z $ALLOW || -f $ALLOW ]] || die "no such allow file: $ALLOW"

meta() { sed -n "s/^$2=//p" "$1/meta.txt" 2>/dev/null | head -1; }
status=0
note() { printf 'note: %s\n' "$*"; }

scale=$(meta "$NEW" scale)
[[ -n $scale && -n $(meta "$BASE" scale) ]] || die "both directories need the meta.txt shoot.sh writes"
for key in scale theme; do
  if [[ $(meta "$BASE" $key) != "$(meta "$NEW" $key)" ]]; then
    echo "FAIL: $key differs: base $(meta "$BASE" $key), new $(meta "$NEW" $key)"
    status=1
  fi
done
same_day=1
if [[ $(meta "$BASE" date) != "$(meta "$NEW" date)" ]]; then
  same_day=
  note "the runs are from different days ($(meta "$BASE" date) vs $(meta "$NEW" date)); date-dependent captures are skipped"
fi
note "base: $(meta "$BASE" source) @ $(meta "$BASE" commit); new: $(meta "$NEW" source) @ $(meta "$NEW" commit)"

allowed() { [[ -n $ALLOW ]] && grep -vE '^\s*(#|$)' "$ALLOW" | sed 's/[[:space:]#].*//' | grep -qxF "$1"; }
date_dependent() { grep -vE '^\s*(#|$)' "$QSV_DIR/date-dependent.txt" | sed 's/[[:space:]#].*//' | grep -qxF "$1"; }

rm -rf "$NEW/diff"
mkdir -p "$NEW/diff"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mapfile -t names < <({
  (cd "$BASE" && ls ./*.png 2>/dev/null)
  (cd "$NEW" && ls ./*.png 2>/dev/null)
} | sed 's|^\./||; s|\.png$||' | sort -u)
[[ ${#names[@]} -gt 0 ]] || die "no captures in either directory"

printf '%-34s %8s  %s\n' CAPTURE PIXELS RESULT
for n in "${names[@]}"; do
  a=$BASE/$n.png
  b=$NEW/$n.png
  if [[ ! -f $a || ! -f $b ]]; then
    side=base
    [[ -f $a ]] && side=new
    printf '%-34s %8s  %s\n' "$n" - "MISSING in $side"
    status=1
    continue
  fi
  if [[ -z $same_day ]] && date_dependent "$n"; then
    printf '%-34s %8s  %s\n' "$n" - "skipped (date-dependent, different days)"
    continue
  fi
  masked "$n" "$scale" "$a" "$tmp/a.png"
  masked "$n" "$scale" "$b" "$tmp/b.png"
  out=$(magick compare -metric AE -fuzz 3% "$tmp/a.png" "$tmp/b.png" "$NEW/diff/$n.png" 2>&1)
  px=${out%% *}
  if [[ $px == 0 ]]; then
    rm -f "$NEW/diff/$n.png"
    if allowed "$n"; then
      printf '%-34s %8s  %s\n' "$n" 0 "ok (allowed, but identical)"
    else
      printf '%-34s %8s  %s\n' "$n" 0 ok
    fi
  elif allowed "$n"; then
    printf '%-34s %8s  %s\n' "$n" "$px" "differs (allowed)"
  else
    [[ $px =~ ^[0-9.]+$ ]] || px="size"
    printf '%-34s %8s  %s\n' "$n" "$px" "DIFFERS  -> $NEW/diff/$n.png"
    status=1
  fi
done

if [[ $status -eq 0 ]]; then
  echo "compare: clean"
else
  echo "compare: FAILED"
fi
exit $status
