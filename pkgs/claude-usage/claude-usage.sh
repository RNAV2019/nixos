creds="$HOME/.claude/.credentials.json"
cache="${XDG_RUNTIME_DIR:-/tmp}/claude-usage.json"

# Re-emit the cached reading with status $1, or exit $2 if there is none.
emit_cached() {
  if [ -r "$cache" ]; then
    jq -ce --arg s "$1" '.status = $s' "$cache" && exit 0
  fi
  exit "$2"
}

[ -r "$creds" ] || emit_cached expired 2

expires=$(jq -r '.claudeAiOauth.expiresAt // 0' "$creds")
[ "$expires" -gt "$(date +%s%3N)" ] || emit_cached expired 2

token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds")
[ -n "$token" ] || emit_cached expired 2

body=$(mktemp)
trap 'rm -f "$body"' EXIT

code=$(curl -s --max-time 10 -o "$body" -w '%{http_code}' \
  https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $token" \
  -H "anthropic-beta: oauth-2025-04-20") || emit_cached stale 1

case "$code" in
  200) ;;
  # The token outlived its expiresAt claim, or the session was revoked.
  401 | 403) emit_cached expired 2 ;;
  # Rate limited, 5xx, or a captive-portal style interception.
  *) emit_cached stale 1 ;;
esac

jq -ce '
    # Epoch seconds, since Qt cannot parse the microseconds from the API.
    def epoch: if . == null then 0 else sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | fromdateiso8601 end;
    {
      status: "ok",
      updated: (now | floor),
      fiveHour: (.five_hour.utilization // 0),
      sevenDay: (.seven_day.utilization // 0),
      fiveHourResets: (.five_hour.resets_at | epoch),
      sevenDayResets: (.seven_day.resets_at | epoch)
    }' < "$body" > "$cache.tmp" || emit_cached stale 1

mv -f "$cache.tmp" "$cache"
cat "$cache"
