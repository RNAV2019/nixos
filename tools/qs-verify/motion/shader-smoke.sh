#!/usr/bin/env bash
# Loads Shaders/roundedclip.frag.qsb, hills.frag.qsb and lockwash.frag.qsb in a real Qt scene graph and checks the clip,
# the hills colour and the wash.
# ShaderEffect needs an RHI GL/Vulkan backend, which the offscreen QPA plugin lacks,
# so this runs under a private headless sway (pixman, no GPU needed). Prints PASS or FAIL.
set -u
cd "$(dirname "$0")"
RT=$(mktemp -d)
chmod 700 "$RT"
QML=$(mktemp --tmpdir="$PWD" smoke-XXXXXX.qml)
OUT=$RT/frame
trap 'kill $SWAYPID 2>/dev/null; rm -rf "$RT" "$QML"' EXIT
sed "s|@OUT@|$OUT|" shader-smoke.qml >"$QML"
export XDG_RUNTIME_DIR=$RT
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  nix shell --inputs-from ../../.. nixpkgs#sway -c sway -c /dev/null >"$RT/sway.log" 2>&1 &
SWAYPID=$!
for _ in $(seq 100); do [[ -S $RT/wayland-1 ]] && break; sleep 0.1; done
[[ -S $RT/wayland-1 ]] || { echo "sway did not start" >&2; exit 1; }
WAYLAND_DISPLAY=wayland-1 QT_QPA_PLATFORM=wayland QT_FORCE_STDERR_LOGGING=1 QSG_RHI_BACKEND=opengl \
  timeout 60 nix shell --inputs-from ../../.. nixpkgs#qt6.qtdeclarative nixpkgs#qt6.qtwayland -c qml "$QML" 2>&1 | grep -v "^MESA\|textinput\|^warning"
alpha() { nix shell --inputs-from ../../.. nixpkgs#imagemagick -c magick "$OUT.$1.png" -format "%[fx:round(255*p{$2}.a)]" info: 2>/dev/null; }
fail=0
expect() { # image x,y want label
  got=$(alpha "$1" "$2")
  [[ $got == "$3" ]] || { echo "FAIL $4 at $2: alpha $got, want $3"; fail=1; }
}
# case 1: item == box
expect 1 1,1 0 "case1 corner"
expect 1 50,50 255 "case1 centre"
expect 1 50,1 255 "case1 edge"
# case 2: item larger than box, nonzero origin (box spans x40-140, y50-110)
expect 2 10,10 0 "case2 outside item corner"
expect 2 30,80 0 "case2 left of box"
expect 2 150,80 0 "case2 right of box"
expect 2 90,40 0 "case2 above box"
expect 2 90,80 255 "case2 box centre"
expect 2 90,51 255 "case2 box top edge"
expect 2 41,51 0 "case2 box corner"
expect 2 139,109 0 "case2 box corner"
chan() { nix shell --inputs-from ../../.. nixpkgs#imagemagick -c magick "$OUT.$1.png" -format "%[fx:round(255*p{$2}.$3)]" info: 2>/dev/null; }
# case 3: hills, three stacked half-alpha red layers (bottom row of the track, mid-width)
r=$(chan 3 50,29 r); a=$(chan 3 50,29 a)
[[ $a -ge 218 && $a -le 228 ]] || { echo "FAIL case3 hills alpha $a, want ~223"; fail=1; }
[[ $r -ge 250 ]] || { echo "FAIL case3 hills red $r, want ~255 (colour multiplied by alpha twice?)"; fail=1; }
# case 4: lockwash, blue inside the wash's core, red past its reach, clear below the source's ink
b=$(chan 4 10,10 b); r=$(chan 4 10,10 r)
[[ $b -ge 250 && $r -le 5 ]] || { echo "FAIL case4 lockwash core r$r b$b, want blue"; fail=1; }
b=$(chan 4 90,10 b); r=$(chan 4 90,10 r)
[[ $r -ge 250 && $b -le 5 ]] || { echo "FAIL case4 lockwash ink r$r b$b, want red"; fail=1; }
expect 4 90,10 255 "case4 ink"
expect 4 50,30 0 "case4 below the source"
[[ $fail == 0 ]] && echo PASS || exit 1
