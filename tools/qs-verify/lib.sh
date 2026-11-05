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

# Nothing of the live session may leak in: every XDG_*, the compositor and bus variables.
scrub_live_env() {
  local v
  for v in $(compgen -e); do
    case $v in
      XDG_* | HYPRLAND_* | SWAYSOCK | DISPLAY | WAYLAND_DISPLAY | DBUS_* | LD_LIBRARY_PATH | LD_PRELOAD | NIRI_* | I3SOCK | QUICKSHELL_* | QS_*) unset "$v" ;;
    esac
  done
}

# Start quickshell on the harness (its environment loaded) inside the bubblewrap namespace that
# swaps sysfs and /proc for the fakes, and wait for ipc. A restart appends to the same log.
start_shell() {
  "$QSV_BWRAP" --dev-bind / / \
    --bind "$QSV_WORK/fake/backlight" /sys/class/backlight \
    --bind "$QSV_WORK/fake/leds" /sys/class/leds \
    --bind "$QSV_WORK/fake/proc/stat" /proc/stat \
    --bind "$QSV_WORK/fake/proc/meminfo" /proc/meminfo \
    quickshell --no-color -p "$QSV_CFG" >>"$QSV_WORK/quickshell.log" 2>&1 &
  echo $! >"$QSV_WORK/quickshell.pid"
  local _
  for _ in $(seq 150); do
    qs -p "$QSV_CFG" ipc show >/dev/null 2>&1 && return 0
    sleep 0.2
  done
  return 1
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

# ---- the phone: a mock kdeconnectd on the private session bus, read by the real phone-bridge ----
# (PH_CALLS, PH_STORAGE and NB_SEND are set by the script that sources this, after load_env.)

ph() { busctl --user call org.mock.Control /control org.mock.Control Apply s "$1" >/dev/null; }
ph_up() { # the mock daemon and a phone with two notifications; kept for the states after it
  ph_fixtures
  busctl --user list 2>/dev/null | grep -q org.mock.Control || {
    setsid "$(mock_python)/bin/python" "$QSV_REPO/pkgs/phone-bridge/tests/mock-kdeconnectd.py" "$PH_CALLS" \
      >"$QSV_WORK/mock-kdeconnectd.log" 2>&1 &
    until busctl --user list 2>/dev/null | grep -q org.mock.Control; do sleep 0.2; done
  }
  ph '{"op":"device","id":"s24","name":"Galaxy S24 Ultra","type":"phone","battery":{"charge":78,"charging":false}}'
  ph '{"op":"cellular","dev":"s24","type":"5G","strength":3}'
  ph "{\"op\":\"sftp\",\"dev\":\"s24\",\"grant\":true,\"mount\":\"$PH_STORAGE\"}"
  ph '{"op":"notify","dev":"s24","id":"n1","app":"WhatsApp","title":"Maya","text":"Dinner on Friday?"}'
  ph '{"op":"notify","dev":"s24","id":"n2","app":"Gmail","title":"Weekly digest","text":"Seven new things in your inbox"}'
  sleep 3
}
# The phone's storage as the mock mounts it, and the laptop's Pictures: the same eight pictures
# (and a PDF and an archive the images-only picker must not list), so the wallpaper pickers have
# something to show and to choose.
ph_fixtures() {
  local root pic i name
  for root in "$PH_STORAGE" "$HOME"; do
    i=0
    if [[ $root == "$HOME" ]]; then
      mkdir -p "$root"/{Desktop,Documents,Downloads,Music,nixos,Projects,Videos}
    else
      mkdir -p "$root"/{DCIM,Documents,Download,Movies,Music,Recordings,Wallpapers}
    fi
    pic=$root/Pictures
    mkdir -p "$pic/Screenshots" "$pic/Wallpapers"
    for name in dusk.jpg forest.jpg IMG_2204.jpg mountains.jpg pier.png sunrise.jpg tokyo.jpg waves.jpg; do
      i=$((i + 1))
      magick -size 1600x900 "gradient:$(printf '#%02x5a7c-#7a%02x4c' $((20 + i * 18)) $((90 - i * 7)))" \
        -fill '#d8a657' -draw "circle $((300 + i * 90)),300 $((300 + i * 90)),420" "$pic/$name"
    done
    : >"$pic/Screenshots/one.png"
    : >"$pic/Screenshots/two.png"
    head -c 3000 /dev/zero >"$pic/notes.pdf"
    head -c 9000 /dev/zero >"$pic/backup.zip"
  done
}

nb_kde_files() {
  mkdir -p "$NB_SEND"
  head -c 2400000 /dev/zero >"$NB_SEND/IMG_2041.jpg"
  head -c 612000 /dev/zero >"$NB_SEND/itinerary.pdf"
  head -c 15400000 /dev/zero >"$NB_SEND/photos-oct.zip"
}
nb_kde_stage() {
  nb_kde_files
  qsipc nearby send "$NB_SEND/IMG_2041.jpg" >/dev/null
  sleep 0.5
  qsipc nearby send "$NB_SEND/itinerary.pdf" >/dev/null
  qsipc nearby send "$NB_SEND/photos-oct.zip" >/dev/null
  sleep 1.2
}

# ---- a media player: a mock MPRIS player on the private session bus (mock-mpris.py) ----
# Not started by shoot.sh, so the committed baselines are unaffected; tests that need media call it.
mpris_up() { # [Playing|Paused]
  busctl --user list 2>/dev/null | grep -q org.mpris.MediaPlayer2.mock && return 0
  setsid "$(mock_python)/bin/python" "$QSV_REPO/tools/qs-verify/mock-mpris.py" "${1:-Playing}" \
    >"$QSV_WORK/mock-mpris.log" 2>&1 &
  until busctl --user list 2>/dev/null | grep -q org.mpris.MediaPlayer2.mock; do sleep 0.2; done
}
