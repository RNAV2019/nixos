#!/usr/bin/env bash
# Loads Shaders/roundedclip.frag.qsb in a real Qt scene graph and checks the clip.
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
[[ $fail == 0 ]] && echo PASS || exit 1
