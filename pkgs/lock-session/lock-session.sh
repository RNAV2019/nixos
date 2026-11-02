# At login Hyprland itself holds the lock, so a failure there leaves a black locked screen.
# Later a failure leaves the desktop open and the shell gone. Hyprland shows the warning.
warn_unlocked() {
  echo "lock-session: $1" >&2
  local message="Session is NOT locked: $1"
  if hyprctl locked -j 2>/dev/null | grep -q '"locked": *true'; then
    message="The lock screen did not start, so the session stays locked: $1. Fix it from Ctrl+Alt+F2."
  fi
  hyprctl notify 3 15000 "rgb(eb6f92)" "$message" >/dev/null 2>&1 || true
  exit 1
}

if ! qs ipc call lock lock >/dev/null 2>&1; then
  # Start via the user manager so it gets the session environment even from a TTY.
  # No --daemonize: systemd would reap the forked child along with the shell.
  # As Hyprland's --locked-cmd this runs before Hyprland exports its variables to the
  # user manager, so pass them on from here.
  systemd-run --user --collect --quiet --unit=quickshell-shell \
    -E WAYLAND_DISPLAY -E DISPLAY -E HYPRLAND_INSTANCE_SIGNATURE -E XDG_CURRENT_DESKTOP \
    "$(command -v quickshell)" >/dev/null 2>&1 || true

  accepted=false
  for _ in $(seq 1 100); do
    sleep 0.1
    if qs ipc call lock lock >/dev/null 2>&1; then
      accepted=true
      break
    fi
  done

  if [[ "$accepted" != true ]]; then
    warn_unlocked "quickshell did not accept a lock request"
  fi
fi

for _ in $(seq 1 100); do
  if [[ "$(qs ipc call lock secure 2>/dev/null || true)" == true ]]; then
    exit 0
  fi
  sleep 0.1
done

warn_unlocked "the compositor did not secure the session"
