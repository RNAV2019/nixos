#!/usr/bin/env bash
# Loads Shaders/roundedclip.frag.qsb in a real Qt scene graph and checks the clip.
# ShaderEffect needs an RHI GL/Vulkan backend, which the offscreen QPA plugin lacks,
# so this runs under a private headless sway (pixman, no GPU needed). Prints PASS or FAIL.
set -u
cd "$(dirname "$0")"
RT=$(mktemp -d)
chmod 700 "$RT"
trap 'kill $SWAYPID 2>/dev/null; rm -rf "$RT"' EXIT
export XDG_RUNTIME_DIR=$RT
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  nix shell --inputs-from ../../.. nixpkgs#sway -c sway -c /dev/null >"$RT/sway.log" 2>&1 &
SWAYPID=$!
for _ in $(seq 100); do [[ -S $RT/wayland-1 ]] && break; sleep 0.1; done
[[ -S $RT/wayland-1 ]] || { echo "sway did not start" >&2; exit 1; }
WAYLAND_DISPLAY=wayland-1 QT_QPA_PLATFORM=wayland QT_FORCE_STDERR_LOGGING=1 QSG_RHI_BACKEND=opengl \
  timeout 60 nix shell --inputs-from ../../.. nixpkgs#qt6.qtdeclarative nixpkgs#qt6.qtwayland -c qml shader-smoke.qml 2>&1 | grep -v "^MESA\|textinput"
alpha() { nix shell --inputs-from ../../.. nixpkgs#imagemagick -c magick /tmp/qs-shader-smoke.png -format "%[fx:round(255*p{$1}.a)]" info:; }
c=$(alpha 1,1) m=$(alpha 50,50) e=$(alpha 50,1)
if [[ $c == 0 && $m == 255 && $e == 255 ]]; then echo PASS; else echo "FAIL corner=$c centre=$m edge=$e"; exit 1; fi
