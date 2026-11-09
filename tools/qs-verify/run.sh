#!/usr/bin/env bash
# run.sh CONFIG_DIR — start the headless harness and the shell from a copy of CONFIG_DIR.
#
# Starts, all under $QSV_WORK and none of it touching the live session: a headless sway
# (1920x1080, scale $QS_SCALE or 1), two private dbus-daemons (session and system, so UPower,
# NetworkManager and friends are absent rather than live), a private PipeWire + WirePlumber with
# a null sink and source, a fake Handy socket, and quickshell inside a bubblewrap mount
# namespace that swaps sysfs backlight/LEDs and /proc/{stat,meminfo} for fixed fakes.
# Writes $QSV_WORK/env.sh for shoot.sh to source.
#
#   QS_SCALE=1.25 run.sh CONFIG_DIR     the fractional-scale scenario
#   QS_REFRESH=120 run.sh CONFIG_DIR    the headless output refresh rate in Hz (default 60)
#   QS_MOTION_LOG=1 run.sh CONFIG_DIR   the shell logs its motion springs (read by motion/record.sh)
#   QS_THEME=dark run.sh CONFIG_DIR     a theme other than the live one
#   QS_VERIFY_WORK=/tmp/x run.sh ...    a second harness side by side
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[[ $# -eq 1 && -d $1 ]] || die "usage: run.sh CONFIG_DIR"
SRC=$(cd "$1" && pwd)
[[ -f $SRC/shell.qml ]] || die "$SRC has no shell.qml"

SCALE=${QS_SCALE:-1}

# One harness at a time per work dir.
if [[ -f $QSV_ENV ]]; then
  die "a harness is already set up in $QSV_WORK; run stop.sh first"
fi

# The theme the live shell runs, read before the environment is replaced.
REAL_THEME_FILE=${XDG_STATE_HOME:-$HOME/.local/state}/theme/name
THEME=${QS_THEME:-}
if [[ -z $THEME ]]; then
  [[ -f $REAL_THEME_FILE ]] || die "no $REAL_THEME_FILE to copy; set QS_THEME"
  THEME=$(<"$REAL_THEME_FILE")
fi
REAL_EMOJI=$(readlink -f "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell/emoji.tsv" || true)
REAL_PATH=$PATH

# ---- tools ----

mapfile -t TOOL_PATHS < <(tool_paths)
TOOL_BINS=
for p in "${TOOL_PATHS[@]}"; do
  [[ -d $p/bin ]] && TOOL_BINS+=$p/bin:
done
tool() { # the store path of the first output that has bin/NAME
  local p
  for p in "${TOOL_PATHS[@]}"; do
    [[ -x $p/bin/$1 ]] && {
      echo "$p/bin/$1"
      return
    }
  done
  die "tool $1 not found in the nix build"
}

# ---- the scratch world ----

rm -rf "$QSV_WORK"
RT=$QSV_WORK/rt
SCRATCH_HOME=$QSV_WORK/home
CFG=$QSV_WORK/cfg
mkdir -p "$RT" "$SCRATCH_HOME/.local/state/theme" "$SCRATCH_HOME/.cache" "$SCRATCH_HOME/.config" \
  "$SCRATCH_HOME/.local/share" "$QSV_WORK/bin" "$RT/handy"
chmod 700 "$RT"
printf '%s' "$THEME" >"$SCRATCH_HOME/.local/state/theme/name"
# Quickshell insists on this one for the lock's "is it secured" probe; harmless otherwise.
: >"$RT/quickshell-secured-"

# Opt-in switches for the shell itself (motion recorder), kept across the scrub.
MOTION_LOG=${QS_MOTION_LOG:-}
REFRESH=${QS_REFRESH:-60}
# The compositor's renderer: pixman (default, the same pixels everywhere) or gles2 (the GPU, for
# motion: pixman paints a full 1080p frame too slowly to keep 120 Hz).
RENDERER=${QS_RENDERER:-pixman}
REDUCE_MOTION=${QUICKSHELL_REDUCE_MOTION:-}

scrub_live_env

export HOME=$SCRATCH_HOME
export XDG_RUNTIME_DIR=$RT
export XDG_CACHE_HOME=$HOME/.cache XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share XDG_STATE_HOME=$HOME/.local/state
export XDG_DATA_DIRS=$QSV_WORK/share
export TZ=UTC LANG=C.UTF-8
export PATH=$QSV_WORK/bin:$TOOL_BINS$REAL_PATH

# Fixture applications, so the launcher lists the same apps whatever is installed.
mkdir -p "$QSV_WORK/share/applications"
for app in "Files:system-file-manager" "Terminal:utilities-terminal" "Web Browser:web-browser" \
  "Text Editor:accessories-text-editor" "Music:multimedia-audio-player" "Settings:preferences-system"; do
  name=${app%%:*}
  printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\nIcon=%s\nCategories=Utility;\n' \
    "$name" "${app#*:}" >"$QSV_WORK/share/applications/${name// /-}.desktop"
done

# Commands the shell runs that must not reach the real machine.
printf '#!/bin/sh\nexit 0\n' >"$QSV_WORK/bin/brightnessctl"
printf '#!/bin/sh\nexit 1\n' >"$QSV_WORK/bin/hyprctl"
# The real one names the scratch config path in its error, which moves with QS_VERIFY_WORK.
printf '#!/bin/sh\necho "ical-agenda: no calendar addresses in ~/.config/quickshell-calendar/ical-urls" >&2\nexit 1\n' \
  >"$QSV_WORK/bin/ical-agenda"
chmod +x "$QSV_WORK/bin/brightnessctl" "$QSV_WORK/bin/hyprctl" "$QSV_WORK/bin/ical-agenda"

# `nearby`, the CLI of nearbyd: the shell reads one long-lived `nearby events` stream and a
# `transfers --json` dump. The stub replays a baseline status and then whatever shoot.sh appends
# to nearby.events, so the peers, offers and transfers can be driven without the daemon.
cat >"$QSV_WORK/bin/nearby" <<STUB
#!/bin/sh
case "\$1" in
  events)
    cat "$QSV_WORK/nearby.baseline"
    exec tail -n0 -F "$QSV_WORK/nearby.events"
    ;;
  transfers) echo '[]' ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$QSV_WORK/bin/nearby"
: >"$QSV_WORK/nearby.events"
echo '{"event":"status","status":{"mode":"android","visible":false,"remaining":null,"scanning":false,"busy":false,"name":"test-laptop","download_dir":"/tmp/Downloads","android":{"running":true,"port":47713,"error":null},"apple":{"available":true,"receiving":false,"visible":null,"reason":null,"error":null}}}' >"$QSV_WORK/nearby.baseline"


# The phone panel's Browse opens the phone's mount in `nautilus`, started in a systemd scope.
# Neither runs: the scope launcher logs what it was asked to start, and shoot.sh checks the log.
cat >"$QSV_WORK/bin/systemd-run" <<STUB
#!/bin/sh
while [ \$# -gt 0 ] && [ "\$1" != "--" ]; do shift; done
shift
echo "\$*" >>"$QSV_WORK/launched.log"
STUB
chmod +x "$QSV_WORK/bin/systemd-run"
: >"$QSV_WORK/launched.log"

# `wl-screenrec`, which the recorder execs: it says why it cannot capture and leaves no file, so
# the recorder reports a failed recording, as it does on a compositor without screencopy.
printf '#!/bin/sh\necho "Error: the compositor offers no screencopy (qs-verify stub)" >&2\nexit 1\n' \
  >"$QSV_WORK/bin/wl-screenrec"
chmod +x "$QSV_WORK/bin/wl-screenrec"

# `cliphist`, which the phone panel lists the newest clips from: a fixed history, nothing stored.
cat >"$QSV_WORK/bin/cliphist" <<STUB
#!/bin/sh
case "\$1" in
  -preview-width) cat "$QSV_WORK/cliphist.list" ;;
  decode) exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$QSV_WORK/bin/cliphist"
printf '3\thttps://nixos.org/manual/nixos/stable\n2\tmeeting notes for friday\n1\tssh ryan@192.168.1.20\n' >"$QSV_WORK/cliphist.list"

# Fixture wallpapers (the pickers list ~/Pictures/backgrounds/<theme>/), and the compositor's
# own background: a gradient with shapes in it, so a panel's translucency and blur show.
MAGICK=$(tool magick)
for t in ariadne dark rose-pine; do
  mkdir -p "$HOME/Pictures/backgrounds/$t"
  i=0
  for pair in "#355c7d-#c06c84" "#2b5876-#4e4376" "#134e5e-#71b280" "#41295a-#2f0743"; do
    i=$((i + 1))
    "$MAGICK" -size 640x360 "gradient:$pair" "$HOME/Pictures/backgrounds/$t/wall-$i.png"
  done
done
"$MAGICK" -size 1920x1080 gradient:'#3d3556-#1f4f55' \
  -fill '#d8a657' -draw 'circle 420,520 420,720' -fill '#7daea3' -draw 'rectangle 1100,380 1500,980' \
  -fill '#ea6962' -draw 'circle 1650,200 1650,300' "$QSV_WORK/bg.png"

# Fake sysfs / procfs, bind-mounted over the real ones for the shell only.
mkdir -p "$QSV_WORK/fake/backlight/panel" "$QSV_WORK/fake/leds/test::kbd_backlight" "$QSV_WORK/fake/proc"
echo 960 >"$QSV_WORK/fake/backlight/panel/max_brightness"
echo 480 >"$QSV_WORK/fake/backlight/panel/brightness"
echo 3 >"$QSV_WORK/fake/leds/test::kbd_backlight/max_brightness"
echo 1 >"$QSV_WORK/fake/leds/test::kbd_backlight/brightness"
echo 'cpu  100 0 100 800 0 0 0 0 0 0' >"$QSV_WORK/fake/proc/stat"
printf 'MemTotal:       16000000 kB\nMemFree:         6000000 kB\nMemAvailable:    8000000 kB\n' >"$QSV_WORK/fake/proc/meminfo"
mkdir -p "$QSV_WORK/fake/power"
echo "Fast [Standard] Long_Life" >"$QSV_WORK/fake/power/charge_types"

# ---- the shell's config: a copy, patched ----

cp -rL "$SRC" "$CFG"
chmod -R u+w "$CFG"

patch_file() { # FILE SED-EXPR DESCRIPTION: apply, and fail when it changed nothing
  local file=$1 expr=$2 what=$3
  [[ -f $file ]] || die "patch '$what': $file is missing"
  cp "$file" "$file.orig"
  sed -E -i "$expr" "$file"
  if cmp -s "$file" "$file.orig"; then
    die "patch '$what' did not apply to $file; update tools/qs-verify/run.sh for the new code"
  fi
  rm "$file.orig"
}

# Sway has no Hyprland focus, so every surface would think it is on an unfocused output.
patch_file "$CFG/Commons/Monitors.qml" \
  's/^(\s*)return screen !== null && Hyprland\.focusedMonitor !== null.*$/\1return screen !== null;/' \
  "Monitors.isFocused"
# The OLED orbit moves the pill one pixel every three minutes; a run takes longer than that.
oled=$(grep -rlE 'readonly property int oledShiftInterval: ' "$CFG" --include='*.qml' | head -1 || true)
[[ -n $oled ]] || die "patch 'OLED orbit': oledShiftInterval not found"
patch_file "$oled" 's/(readonly property int oledShiftInterval: )[0-9]+/\12000000000/' "OLED orbit"

# ---- private buses ----

cat >"$QSV_WORK/dbus.conf" <<'XML'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
XML
DBUSD=$(tool dbus-daemon)
for bus in session system; do
  "$DBUSD" --config-file="$QSV_WORK/dbus.conf" --fork \
    --print-address=3 --print-pid=4 3>"$QSV_WORK/$bus.addr" 4>"$QSV_WORK/$bus.pid"
done
export DBUS_SESSION_BUS_ADDRESS DBUS_SYSTEM_BUS_ADDRESS
DBUS_SESSION_BUS_ADDRESS=$(tr -d '\n' <"$QSV_WORK/session.addr")
DBUS_SYSTEM_BUS_ADDRESS=$(tr -d '\n' <"$QSV_WORK/system.addr")

# ---- audio: a null sink and source, so the volume and mic OSDs have something to read ----

mkdir -p "$XDG_CONFIG_HOME/pipewire/pipewire.conf.d" "$XDG_CONFIG_HOME/wireplumber/wireplumber.conf.d"
cat >"$XDG_CONFIG_HOME/pipewire/pipewire.conf.d/10-qsv.conf" <<'EOF'
context.objects = [
  { factory = adapter
    args = { factory.name = support.null-audio-sink node.name = "qsv-sink"
             node.description = "Test Speakers" media.class = Audio/Sink
             object.linger = true audio.position = [ FL FR ] } }
  { factory = adapter
    args = { factory.name = support.null-audio-sink node.name = "qsv-source"
             node.description = "Test Microphone" media.class = Audio/Source
             object.linger = true audio.position = [ FL FR ] } }
]
EOF
cat >"$XDG_CONFIG_HOME/wireplumber/wireplumber.conf.d/10-qsv.conf" <<'EOF'
wireplumber.profiles = {
  main = {
    hardware.audio = disabled
    hardware.bluetooth = disabled
    hardware.video-capture = disabled
  }
}
EOF
"$(tool pipewire)" >"$QSV_WORK/pipewire.log" 2>&1 &
sleep 1
"$(tool wireplumber)" >"$QSV_WORK/wireplumber.log" 2>&1 &
wp() { wpctl "$@" 2>/dev/null; }
for _ in $(seq 100); do
  wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && wpctl inspect @DEFAULT_AUDIO_SOURCE@ >/dev/null 2>&1 && break
  sleep 0.2
done
wp inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 || die "the null sink never became the default; see $QSV_WORK/wireplumber.log"
wp set-mute @DEFAULT_AUDIO_SINK@ 0
wp set-volume @DEFAULT_AUDIO_SINK@ 0.40
wp set-mute @DEFAULT_AUDIO_SOURCE@ 0
wp set-volume @DEFAULT_AUDIO_SOURCE@ 0.80

# ---- the compositor ----

cat >"$QSV_WORK/sway.conf" <<EOF
output HEADLESS-1 mode 1920x1080@${REFRESH}Hz scale $SCALE
output * bg $QSV_WORK/bg.png fill
default_border none
EOF
WLR_BACKENDS=headless WLR_RENDERER=$RENDERER WLR_LIBINPUT_NO_DEVICES=1 \
  "$(tool sway)" -c "$QSV_WORK/sway.conf" >"$QSV_WORK/sway.log" 2>&1 &
for _ in $(seq 100); do
  [[ -S $RT/wayland-1 ]] && break
  sleep 0.1
done
[[ -S $RT/wayland-1 ]] || die "sway did not come up; see $QSV_WORK/sway.log"
export WAYLAND_DISPLAY=wayland-1
SWAYSOCK=$(find "$RT" -maxdepth 1 -name "sway-ipc.*.sock" | head -1)
export SWAYSOCK

# ---- a virtual pointer: headless sway has no input devices, so no hover or clicks without one ----

build_vpointer "$QSV_CACHE/vpointer"
mkfifo "$QSV_WORK/vpointer.fifo"
# A writer held open for the whole run, so vpointer does not see end-of-file between commands.
(while :; do sleep 3600; done) >"$QSV_WORK/vpointer.fifo" 2>/dev/null </dev/null &
read -r EXT_W EXT_H < <(awk -v s="$SCALE" 'BEGIN { printf "%f %f\n", 1920 / s, 1080 / s }')
"$QSV_CACHE/vpointer" --extent "$EXT_W" "$EXT_H" --script "$QSV_WORK/vpointer.fifo" >"$QSV_WORK/vpointer.log" 2>&1 &

# ---- Handy's overlay socket, served from a file the screenshot script appends to ----

: >"$QSV_WORK/dictation.events"
"$(tool socat)" "UNIX-LISTEN:$RT/handy/overlay.sock,fork" \
  "EXEC:tail -n0 -F $QSV_WORK/dictation.events" >"$QSV_WORK/socat.log" 2>&1 &

# ---- the environment the other scripts use ----

# The shell's own, kept in env.sh so restart.sh starts it the same way.
export QS_EMOJI_DATA=$REAL_EMOJI
export QUICKSHELL_CHARGE_TYPES=$QSV_WORK/fake/power/charge_types
# The recorder switches reach the shell itself (env.sh keeps them for restart.sh).
[[ -z $MOTION_LOG ]] || export QS_MOTION_LOG=$MOTION_LOG
[[ -z $REDUCE_MOTION ]] || export QUICKSHELL_REDUCE_MOTION=$REDUCE_MOTION
QSV_BWRAP=$(tool bwrap)
QSV_CFG=$CFG

{
  echo "# written by run.sh; sourced by shoot.sh"
  for v in HOME XDG_RUNTIME_DIR XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_DATA_DIRS \
    TZ LANG PATH DBUS_SESSION_BUS_ADDRESS DBUS_SYSTEM_BUS_ADDRESS WAYLAND_DISPLAY SWAYSOCK \
    QS_EMOJI_DATA QUICKSHELL_CHARGE_TYPES; do
    printf 'export %s=%q\n' "$v" "${!v}"
  done
  printf 'export QSV_CFG=%q QSV_SCALE=%q QSV_THEME=%q QSV_SRC=%q\n' "$CFG" "$SCALE" "$THEME" "$SRC"
  printf 'export QSV_BWRAP=%q\n' "$QSV_BWRAP"
  [[ -z $MOTION_LOG ]] || printf 'export QS_MOTION_LOG=%q\n' "$MOTION_LOG"
  [[ -z $REDUCE_MOTION ]] || printf 'export QUICKSHELL_REDUCE_MOTION=%q\n' "$REDUCE_MOTION"
  printf 'unset LD_LIBRARY_PATH\n'
} >"$QSV_ENV"

# ---- the shell ----

if ! start_shell; then
  cat "$QSV_WORK/quickshell.log" >&2
  die "quickshell never answered ipc"
fi
# Singletons start on first use and the OSD ignores signals for its first dwell.
sleep 4

# ---- a clean load, or loudly not ----

bad=$(grep -E '(^| )(WARN|ERROR|FATAL)\b' "$QSV_WORK/quickshell.log" || true)
if [[ -f $QSV_DIR/allowed-log.txt ]]; then
  # Known, explained lines (regexes, one per line, # comments).
  allowed=$(grep -vE '^\s*(#|$)' "$QSV_DIR/allowed-log.txt" || true)
  [[ -n $allowed && -n $bad ]] && bad=$(grep -vE "$(paste -sd'|' <<<"$allowed")" <<<"$bad" || true)
fi
if [[ -n $bad ]]; then
  echo "qs-verify: quickshell logged warnings or errors at load:" >&2
  echo "$bad" >&2
  echo "(full log: $QSV_WORK/quickshell.log; the harness is left running, stop.sh tears it down)" >&2
  exit 2
fi

echo "qs-verify: harness up (theme $THEME, scale $SCALE, work $QSV_WORK, source $SRC)"
