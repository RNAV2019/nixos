#!/usr/bin/env bash
# Shared by the qs-verify scripts: where the harness lives and a few helpers. Sourced, not run.

QSV_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QSV_REPO=$(cd "$QSV_DIR/../.." && pwd)

# Everything the harness starts lives under here (its own runtime dir, HOME, buses, logs).
# A second harness at the same time (another worktree) needs its own QS_VERIFY_WORK.
QSV_WORK=${QS_VERIFY_WORK:-/tmp/qs-verify-$(id -un)}
QSV_ENV=$QSV_WORK/env.sh
# Built tools that outlive a harness run.
export QSV_CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/qs-verify

die() {
  echo "qs-verify: $*" >&2
  exit 1
}

# The harness's environment (written by run.sh). Exports the scratch XDG_* dirs, so only the
# scripts that talk to the shell source it; stop.sh must not.
load_env() {
  [[ -f $QSV_ENV ]] || die "the harness is not running (no $QSV_ENV); run run.sh first"
  # shellcheck source=/dev/null
  source "$QSV_ENV"
}

# Resolve the tools from the repo's own nixpkgs pin, so a baseline and a later run use the same
# sway, grim and ImageMagick. Prints their store paths, one per line.
tool_paths() {
  local out
  out=$(nix build --inputs-from "$QSV_REPO" --no-link --print-out-paths \
    nixpkgs#sway nixpkgs#grim nixpkgs#wtype nixpkgs#imagemagick nixpkgs#socat nixpkgs#dbus \
    nixpkgs#libnotify nixpkgs#pipewire nixpkgs#wireplumber nixpkgs#bubblewrap \
    "$QSV_REPO#phone-bridge" \
    2>&1) || die "nix build of the tools failed:
$out"
  printf '%s\n' "$out"
}

# A python with dbus-fast, to run the mock kdeconnectd (pkgs/phone-bridge/tests) on the private
# session bus.
mock_python() {
  nix build --impure --no-link --print-out-paths --expr \
    "(builtins.getFlake \"path:$QSV_REPO\").inputs.nixpkgs.legacyPackages.\${builtins.currentSystem}.python3.withPackages (ps: [ps.dbus-fast])" || die "no python with dbus-fast"
}

# ---- driving the running shell (after load_env) ----

qsipc() { qs ipc -p "$QSV_CFG" call "$@"; }

# Keys into the focused surface. wtype in headless sway drops the first key of each call, so
# every call leads with a throwaway Shift.
keys() { wtype -k Shift_L "$@"; }
type_text() { wtype -k Shift_L -s 40 "$1"; }

# The pointer (run.sh keeps a virtual one alive on a fifo), in logical px.
cursor() { printf 'abs %s %s\n' "$1" "$2" >"$QSV_WORK/vpointer.fifo"; }
click() { printf 'click\n' >"$QSV_WORK/vpointer.fifo"; }

# ---- masks ----
#
# masks.txt: "GLOB X Y W H" per line, in logical px, for regions that legitimately differ run to
# run (the clock). Painted over before two frames are compared.

# magick arguments painting the masks that apply to NAME, scaled to the scenario.
mask_args() {
  local name=$1 scale=${2:-1} glob x y w h
  while read -r glob x y w h _; do
    [[ -z $glob || $glob == \#* ]] && continue
    # shellcheck disable=SC2053
    [[ $name == $glob ]] || continue
    awk -v x="$x" -v y="$y" -v w="$w" -v h="$h" -v s="$scale" 'BEGIN {
      printf "-fill\nblack\n-draw\nrectangle %d,%d %d,%d\n", x * s, y * s, (x + w) * s - 1, (y + h) * s - 1 }'
  done <"$QSV_DIR/masks.txt"
}

# masked NAME SCALE IN OUT: IN with NAME's masks painted over, written to OUT.
masked() {
  local args
  mapfile -t args < <(mask_args "$1" "$2")
  magick "$3" "${args[@]}" "$4"
}

# ---- the virtual pointer ----

# build_vpointer OUT: compile vpointer.c (the scripted zwlr_virtual_pointer client) into OUT,
# with the compiler and protocol XML from the repo's nixpkgs.
build_vpointer() {
  local out=$1 wl_dev wl_lib scanner wlr cc xml
  [[ -x $out ]] && return 0
  pkg() { nix build --inputs-from "$QSV_REPO" --no-link --print-out-paths "nixpkgs#$1" | head -n1; }
  wl_dev=$(pkg 'wayland^dev')
  wl_lib=$(pkg 'wayland^out')
  scanner=$(pkg 'wayland-scanner^bin')
  wlr=$(pkg wlr-protocols)
  cc=$(pkg 'gcc^out')/bin/gcc
  xml=$(find "$wlr" -name 'wlr-virtual-pointer-unstable-v1.xml' | head -n1)
  [[ -n $xml && -x $cc ]] || die "could not find the compiler or the wlr-virtual-pointer protocol"
  local tmp
  tmp=$(mktemp -d)
  mkdir -p "$(dirname "$out")"
  "$scanner/bin/wayland-scanner" client-header "$xml" "$tmp/wlr-virtual-pointer-unstable-v1-client-protocol.h"
  "$scanner/bin/wayland-scanner" private-code "$xml" "$tmp/wlr-vp.c"
  "$cc" -o "$out" "$QSV_DIR/vpointer.c" "$tmp/wlr-vp.c" -O2 -Wall -Wno-unused-parameter \
    -I"$tmp" -I"$wl_dev/include" -L"$wl_lib/lib" -Wl,-rpath,"$wl_lib/lib" -lwayland-client -lm \
    || die "vpointer failed to build"
  rm -rf "$tmp"
}

# ImageMagick for the scripts that run without the harness (compare.sh): the repo's pin.
need_magick() {
  command -v magick >/dev/null 2>&1 && return 0
  local p
  p=$(nix build --inputs-from "$QSV_REPO" --no-link --print-out-paths nixpkgs#imagemagick 2>/dev/null | head -n1)
  [[ -x $p/bin/magick ]] || die "ImageMagick is not on PATH and could not be built"
  PATH=$p/bin:$PATH
}
