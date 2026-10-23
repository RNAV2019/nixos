#!/usr/bin/env bash
# Build the test clients (dragsrc, vpointer) into $BIN (default /tmp/dragpile-test/bin), with
# compilers and protocol XML from the repo's nixpkgs.
#
# usage: build.sh            then e.g. DRAGSRC=$BIN/dragsrc test/run.sh …
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
BIN=${BIN:-/tmp/dragpile-test/bin}
mkdir -p "$BIN"

pkg() {
  nix build --impure --no-link --print-out-paths --expr \
    "let pkgs = import (builtins.getFlake \"$REPO\").inputs.nixpkgs { system = \"x86_64-linux\"; }; in pkgs.$1" | head -n1
}
WAYLAND=$(pkg wayland.dev)
WLIB=$(pkg wayland.out)
SCANNER=$(pkg wayland-scanner.bin)
PROTOS=$(pkg wayland-protocols)
WLR=$(pkg wlr-protocols)
CC=$(pkg gcc.out)/bin/gcc

xml_wlr=$(find "$WLR" -name 'wlr-virtual-pointer-unstable-v1.xml' | head -n1)
xml_xdg=$PROTOS/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml
"$SCANNER/bin/wayland-scanner" client-header "$xml_wlr" "$BIN/wlr-virtual-pointer-unstable-v1-client-protocol.h"
"$SCANNER/bin/wayland-scanner" private-code "$xml_wlr" "$BIN/wlr-vp.c"
"$SCANNER/bin/wayland-scanner" client-header "$xml_xdg" "$BIN/xdg-shell-client-protocol.h"
"$SCANNER/bin/wayland-scanner" private-code "$xml_xdg" "$BIN/xdg-shell.c"

flags=(-O2 -Wall -Wno-unused-parameter -I"$BIN" -I"$WAYLAND/include" -L"$WLIB/lib" -Wl,-rpath,"$WLIB/lib" -lwayland-client -lm)
"$CC" -o "$BIN/dragsrc" "$HERE/dragsrc.c" "$BIN/wlr-vp.c" "$BIN/xdg-shell.c" "${flags[@]}"
"$CC" -o "$BIN/vpointer" "$HERE/vpointer.c" "$BIN/wlr-vp.c" "${flags[@]}"
echo "$BIN/dragsrc"
echo "$BIN/vpointer"
