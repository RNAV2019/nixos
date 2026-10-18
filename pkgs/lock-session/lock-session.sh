# Failure leaves the desktop open and the shell gone, so Hyprland shows the warning.
warn_unlocked() {
  echo "lock-session: $1" >&2
  hyprctl notify 3 15000 "rgb(eb6f92)" "Session is NOT locked: $1" >/dev/null 2>&1 || true
  exit 1
}

if ! qs ipc call lock lock >/dev/null 2>&1; then
  # Start via the user manager so it gets the session environment even from a TTY.
  # No --daemonize: systemd would reap the forked child along with the shell.
  systemd-run --user --collect --quiet --unit=quickshell-shell \
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
