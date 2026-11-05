#!/usr/bin/env bash
# Compile home/quickshell/Shaders/*.{frag,vert} to committed .qsb files.
#   tools/qs-shaders.sh           regenerate every .qsb in place
#   tools/qs-shaders.sh --check   compile to a temp dir, cmp against committed; exit 1 if stale/missing
# Uses the flake's pinned nixpkgs so the qsb output matches the flake check byte for byte.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dir=$root/home/quickshell/Shaders
check=0
[ "${1:-}" = --check ] && check=1

if ! command -v qsb >/dev/null; then
  exec nix shell --inputs-from "$root" nixpkgs#qt6.qtshadertools -c "$0" "$@"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
shopt -s nullglob
for src in "$dir"/*.frag "$dir"/*.vert; do
  name=$(basename "$src")
  committed=$src.qsb
  if [ $check = 1 ]; then
    if [ ! -f "$committed" ]; then
      echo "missing: $name.qsb" >&2
      status=1
      continue
    fi
    qsb --qt6 -o "$tmp/$name.qsb" "$src"
    if ! cmp -s "$tmp/$name.qsb" "$committed"; then
      echo "stale: $name.qsb" >&2
      status=1
    fi
  else
    qsb --qt6 -o "$committed" "$src"
    echo "built $name.qsb"
  fi
done
exit $status
