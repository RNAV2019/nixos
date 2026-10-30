# xdph runs this for a screen-share request and reads stdout for one line,
#   [SELECTION]<flags>/screen:NAME | /window:ID | /region:NAME@x,y,w,h
# where flag r asks for a restore token; no such line cancels. xdph blocks on us
# (nothing else in the portal runs meanwhile), so every wait below has a limit.
#
# The shell draws the choice: `sharepicker ask` hands it the request and returns at once,
# the answer comes back through a FIFO as <flags>/<screen:NAME | window:ID | region>.
# Region is the one thing the shell cannot finish, so it is drawn here with slurp, after
# the surface is gone. Without a shell to answer, the stock picker runs instead.

deadline=180

# The same ordering the shell would otherwise guess at: most recently focused first.
clients=$(hyprctl clients -j 2>/dev/null) || clients='[]'
[[ -n "$clients" ]] || clients='[]'

# XDPH_WINDOW_SHARING_LIST is id[HC>]class[HT>]title[HE>]address[HA>] per window, the
# address being Hyprland's, in decimal. The id is xdph's own and is what it expects back.
windows=$(printf '%s\n' "${XDPH_WINDOW_SHARING_LIST:-}" | jq -Rc --argjson clients "$clients" '
  def hex: if . < 16 then "0123456789abcdef"[. : . + 1]
           else ((. / 16 | floor) | hex) + "0123456789abcdef"[. % 16 : . % 16 + 1] end;
  ($clients | map({key: .address, value: .focusHistoryID}) | from_entries) as $focus
  | split("[HA>]")
  | map(select(length > 0)
      | capture("^(?<id>[0-9]+)\\[HC>\\](?<class>.*?)\\[HT>\\](?<title>.*?)\\[HE>\\](?<address>[0-9]*)$"; "s")
      | {id: (.id | tonumber), class, title,
         address: (if .address == "" or .address == "0" then "" else (.address | tonumber | hex) end)}
      | . + {focus: ($focus["0x" + .address] // 1000000)})
  | sort_by(.focus)
  | map(del(.focus))' 2>/dev/null) || windows='[]'
[[ -n "$windows" ]] || windows='[]'

token=false
for arg in "$@"; do
  [[ "$arg" == --allow-token ]] && token=true
done

dir=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/share-picker.XXXXXX")
answer="$dir/answer"
mkfifo "$answer"

cancel() {
  timeout 3 qs ipc call sharepicker cancel "$answer" >/dev/null 2>&1 || true
}

cleanup() {
  rm -rf "$dir"
}
trap cleanup EXIT
trap 'cancel; exit 0' INT TERM HUP

# Opened for both directions, so neither the shell's write nor our read ever blocks on
# the other end being there.
exec 3<>"$answer"

# One argument that is always an object: qs ipc drops an empty or bare [] argument.
request=$(jq -nc --argjson windows "$windows" --argjson token "$token" --arg app "${XDPH_APP_ID:-}" '{windows: $windows, token: $token, app: $app}')

status=$(timeout 5 qs ipc call sharepicker ask "$answer" "$request" 2>/dev/null) || status=unreachable
case "$status" in
ok) ;;
# Screen locked: nothing may be shared from behind it.
locked) exit 0 ;;
*)
  exec 3>&-
  cleanup
  exec "$stock" "$@"
  ;;
esac

line=""
waited=0
while ((waited < deadline)); do
  if IFS= read -r -t 3 -u 3 line; then
    break
  fi
  line=""
  waited=$((waited + 3))
  alive=$(timeout 3 qs ipc call sharepicker pending "$answer" 2>/dev/null) || alive=gone
  if [[ "$alive" == gone ]]; then
    # The shell went away mid-question; the stock picker still can ask it.
    exec 3>&-
    cleanup
    exec "$stock" "$@"
  fi
  if [[ "$alive" != true ]]; then
    # Closed without an answer, bar one that landed since the last read.
    IFS= read -r -t 0.3 -u 3 line || line=""
    break
  fi
done

if [[ -z "$line" ]]; then
  cancel
  exit 0
fi

flags=${line%%/*}
choice=${line#*/}

if [[ "$choice" == region ]]; then
  # The limit keeps xdph, which waits on us, from hanging behind a selection nobody finishes.
  region=$(timeout 120 slurp -f '%o %x %y %w %h' 2>/dev/null) || exit 0
  read -r output x y w h <<<"$region"
  [[ -n "$output" && -n "$h" ]] || exit 0
  # Selections are relative to the output; slurp reports layout coordinates.
  origin=$(hyprctl monitors -j | jq -r --arg name "$output" '.[] | select(.name == $name) | "\(.x) \(.y)"') || exit 0
  [[ -n "$origin" ]] || exit 0
  read -r ox oy <<<"$origin"
  printf '[SELECTION]%s/region:%s@%d,%d,%d,%d\n' "$flags" "$output" $((x - ox)) $((y - oy)) "$w" "$h"
  exit 0
fi

case "$choice" in
screen:* | window:*) printf '[SELECTION]%s/%s\n' "$flags" "$choice" ;;
esac
