# Toggles a Helium --app window on tinymist's preview for one Helix process,
# closing it when that Helix exits. Mirrors note-tui's session handling.
# Usage: typst-preview-window <url> <helix-pid>
url=$1
editor=$2
base=${XDG_CACHE_HOME:-$HOME/.cache}/typst-preview
state=$base/hx-$editor
mkdir -p "$base"

# A second :preview closes this Helix's window; the watcher below cleans up.
if [ -f "$state" ] && kill -0 "$(cat "$state")" 2>/dev/null; then
  kill -TERM -- "-$(cat "$state")" 2>/dev/null || true
  exit 0
fi

# Drop profiles whose browser is gone. Chromium's SingletonLock points at
# "hostname-pid"; each profile is hundreds of MB, so they can't pile up.
for dir in "$base"/session-*; do
  [ -d "$dir" ] || continue
  if lock=$(readlink "$dir/SingletonLock") && kill -0 "${lock##*-}" 2>/dev/null; then
    continue
  fi
  rm -rf "$dir"
done
for file in "$base"/hx-*; do
  if [ -f "$file" ] && ! kill -0 "${file##*-}" 2>/dev/null; then
    rm -f "$file"
  fi
done

# A fresh profile per window, or Chromium hands the window to the running
# browser and exits, leaving nothing to close.
profile=$(mktemp -d "$base/session-XXXXXX")
setsid helium --app="$url" --user-data-dir="$profile" \
  --no-first-run --no-default-browser-check --disable-extensions \
  >/dev/null 2>&1 &
browser=$!
echo "$browser" >"$state"

# Wait on whichever ends first: the window, or the Helix that opened it.
# (kill -0 alone can't see the browser exit; an unreaped zombie still passes.)
(while kill -0 "$editor" 2>/dev/null; do sleep 1; done) &
watcher=$!
wait -n "$browser" "$watcher" || true
kill "$watcher" 2>/dev/null || true

# Close the whole browser group, killing it if it ignores TERM for 3s.
kill -TERM -- "-$browser" 2>/dev/null || true
(sleep 3 && kill -KILL -- "-$browser" 2>/dev/null) &
killer=$!
wait "$browser" 2>/dev/null || true
kill "$killer" 2>/dev/null || true
rm -rf "$profile" "$state"
