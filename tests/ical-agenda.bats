#!/usr/bin/env bats

# ical-agenda has to print exactly the TSV the quickshell calendar service parses, so most
# of what is checked here is the shape of the output rather than the calendar arithmetic.

setup() {
  test_root=$(mktemp -d)
  export HOME="$test_root/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_CACHE_HOME="$test_root/cache"
  # The fixtures are stamped in UTC, so the local zone has to be fixed.
  export TZ=UTC

  mkdir -p "$HOME" "$test_root/feeds"
  cp "$FIXTURE_DIR"/*.ics "$test_root/feeds/"

  urls="$test_root/urls"
  export QS_CALENDAR_URLS="$urls"
  printf 'file://%s\n' "$test_root/feeds/personal.ics" > "$urls"
}

teardown() {
  rm -rf "$test_root"
}

# The column a header names, mirroring how the QML service reads the TSV: by name.
column() {
  local name=$1 row=$2
  printf '%s\n' "$output" | awk -F'\t' -v want="$name" -v row="$row" '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == want) col = i; next }
    NR == row + 1 { print $col }
  '
}

@test "prints the column header gcalcli printed" {
  run ical-agenda 2026-09-01 2026-09-30
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | head -1)" = "$(printf 'start_date\tstart_time\tend_date\tend_time\ttitle\tcalendar\tlocation')" ]
}

@test "a timed event carries its date, times and location" {
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  [ "$(column start_date 1)" = "2026-09-10" ]
  [ "$(column start_time 1)" = "09:00" ]
  [ "$(column end_date 1)" = "2026-09-10" ]
  [ "$(column end_time 1)" = "10:00" ]
  [ "$(column title 1)" = "Standup" ]
  [ "$(column location 1)" = "Room 3" ]
}

@test "an all-day event leaves both times empty" {
  run ical-agenda 2026-09-12 2026-09-12
  [ "$status" -eq 0 ]
  [ "$(column title 1)" = "Public holiday" ]
  [ "$(column start_time 1)" = "" ]
  [ "$(column end_time 1)" = "" ]
}

@test "an event outside the window is not printed" {
  run ical-agenda 2026-09-01 2026-09-30
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | grep -q "Long gone"
}

@test "a weekly event is expanded to one row per occurrence" {
  run ical-agenda 2026-09-01 2026-09-30
  [ "$status" -eq 0 ]
  # Mondays in the window are the 7th, 14th, 21st and 28th; the 14th is cancelled by EXDATE.
  [ "$(printf '%s\n' "$output" | grep -c 'Weekly sync')" -eq 3 ]
  printf '%s\n' "$output" | grep 'Weekly sync' | grep -q '2026-09-21'
}

@test "an occurrence cancelled by EXDATE is skipped" {
  run ical-agenda 2026-09-14 2026-09-14
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | grep -q "Weekly sync"
}

@test "the calendar column carries the feed name" {
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  [ "$(column calendar 1)" = "Personal" ]
}

@test "a feed with no name falls back to a plain label" {
  printf 'file://%s\n' "$test_root/feeds/unnamed.ics" > "$QS_CALENDAR_URLS"
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  [ "$(column calendar 1)" = "Calendar" ]
}

@test "rows from several feeds are merged in start order" {
  printf 'file://%s\nfile://%s\n' \
    "$test_root/feeds/work.ics" "$test_root/feeds/personal.ics" > "$QS_CALENDAR_URLS"
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  [ "$(column title 1)" = "Standup" ]
  [ "$(column title 2)" = "Design review" ]
}

@test "blank lines and comments in the URL list are ignored" {
  {
    printf '# my calendars\n'
    printf '\n'
    printf 'file://%s\n' "$test_root/feeds/personal.ics"
    printf '   \n'
  } > "$QS_CALENDAR_URLS"
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  [ "$(column title 1)" = "Standup" ]
}

@test "a tab or newline in a title stays inside one row" {
  run ical-agenda 2026-09-11 2026-09-11
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 2 ]
  [ "$(column title 1)" = "Lunch with tabs" ]
}

@test "a missing URL list fails with one line on stderr" {
  rm -f "$QS_CALENDAR_URLS"
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -ne 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
  printf '%s\n' "$output" | grep -q "no calendar"
}

@test "an empty URL list fails rather than printing an empty agenda" {
  : > "$QS_CALENDAR_URLS"
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep -q "no calendar"
}

@test "a feed that cannot be fetched fails and names the feed" {
  printf 'file://%s\n' "$test_root/feeds/absent.ics" > "$QS_CALENDAR_URLS"
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep -q "absent.ics"
}

@test "a second run inside the cache window does not refetch" {
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  rm -f "$test_root/feeds/personal.ics"
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  [ "$(column title 1)" = "Standup" ]
}

@test "--refresh ignores the cache" {
  run ical-agenda 2026-09-10 2026-09-10
  [ "$status" -eq 0 ]
  rm -f "$test_root/feeds/personal.ics"
  run ical-agenda --refresh 2026-09-10 2026-09-10
  [ "$status" -ne 0 ]
}
