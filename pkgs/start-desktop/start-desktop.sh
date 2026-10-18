lock-session

# awww-daemon is a systemd user unit; just wait for its socket.
for _ in $(seq 1 50); do
  if awww query >/dev/null 2>&1; then
    awww img "$HOME/.local/share/wallpaper/current"
    break
  fi
  sleep 0.1
done

nm-applet --indicator &
cliphist wipe || true
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
wait
