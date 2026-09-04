# backup - borg against the NAS repository, with the sharp edges filed off.
#
# BORG_REPO, BORG_PASSCOMMAND, BORG_RSH, BACKUP_UNIT and BACKUP_BORG are baked
# in by modules/system/backups.nix, so this script never learns where a secret
# lives and there is exactly one definition of how to reach the server.

HELIUM_PROFILE="$HOME/.config/net.imput.helium"
MOUNTPOINT="${XDG_RUNTIME_DIR:-/tmp}/backup"

# Rose Pine Moon, to match the rest of the system. Dropped when the output is
# not a terminal, so piping into a file or a log stays readable.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_DIM=$'\033[38;2;110;106;134m'
  C_OK=$'\033[38;2;156;207;216m'
  C_WARN=$'\033[38;2;246;193;119m'
  C_ERR=$'\033[38;2;235;111;146m'
  C_OFF=$'\033[0m'
else
  C_DIM=""
  C_OK=""
  C_WARN=""
  C_ERR=""
  C_OFF=""
fi

interactive() { [[ -t 1 ]]; }

# gum draws its interface on stderr, so it can still ask a question when stdout
# has been captured by a command substitution. That is the descriptor to test
# before offering a chooser.
has_tui() { [[ -t 2 ]]; }

die() {
  printf '%sbackup: %s%s\n' "$C_ERR" "$1" "$C_OFF" >&2
  exit 1
}

ok() { printf '%s%s%s\n' "$C_OK" "$1" "$C_OFF"; }
warn() { printf '%s%s%s\n' "$C_WARN" "$1" "$C_OFF"; }
row() { printf '  %s%-12s%s %s\n' "$C_DIM" "$1" "$C_OFF" "$2"; }

bytes() { numfmt --to=iec-i --suffix=B --format='%.1f' -- "$1"; }

duration() {
  local s=${1%.*}
  if ((s < 60)); then
    printf '%ds\n' "$s"
  elif ((s < 3600)); then
    printf '%dm %ds\n' $((s / 60)) $((s % 60))
  else
    printf '%dh %dm\n' $((s / 3600)) $((s % 3600 / 60))
  fi
}

# gum needs a terminal to draw on, and swallows stdout, so this is only ever
# wrapped around commands whose output we do not need to capture.
spin() {
  local title="$1"
  shift
  if interactive; then
    gum spin --spinner dot --title "$title" --show-error -- "$@"
  else
    "$@"
  fi
}

usage() {
  cat <<'USAGE'
usage: backup <command> [args]

  now [-v]                run a backup now, -v to stream the log instead
                          of a spinner
  status                  last run, next run, size, staleness
  list [ARCHIVE]          list archives, or the files inside one
  restore [PATH...]       choose an archive, then restore those paths from
                          it, or the whole tree if none are given
  restore --archive NAME [PATH...]
                          the same without the picker, for scripts
  mount [ARCHIVE]         browse one archive, or every archive if none is
                          named, then: backup umount
  umount                  unmount it again
  check [--data]          verify integrity, --data reads every chunk

Restoring never picks an archive for you. Retention is deliberately absent:
the server is append-only and pruning needs the admin key. See BACKUPS.md.
USAGE
}

# borg's own message is nearly always the useful one, so it is passed through
# rather than replaced with a guess about what went wrong. Capturing stdout
# separately is what makes that possible.
repo_json() {
  local err out rc=0
  err=$(mktemp)

  out=$("$BACKUP_BORG" "$@" 2>"$err") || rc=$?
  if ((rc != 0)); then
    cat "$err" >&2
    rm -f "$err"
    die "borg exited $rc"
  fi

  rm -f "$err"
  printf '%s' "$out"
}

# One round trip, all the numbers worth seeing after a run.
summarise_latest() {
  local json name nfiles orig comp dedup uniq dur

  json=$(repo_json info --json --last 1)
  read -r name nfiles orig comp dedup uniq dur <<<"$(
    printf '%s' "$json" | jq -r '
      [ .archives[0].name,
        (.archives[0].stats.nfiles          | tostring),
        (.archives[0].stats.original_size   | tostring),
        (.archives[0].stats.compressed_size | tostring),
        (.archives[0].stats.deduplicated_size | tostring),
        (.cache.stats.unique_csize          | tostring),
        (.archives[0].duration              | tostring)
      ] | @tsv'
  )"

  ok "Archived $name"
  row "files" "$(printf "%'d" "$nfiles")"
  row "original" "$(bytes "$orig")"
  row "compressed" "$(bytes "$comp")"
  row "added" "$(bytes "$dedup")"
  row "repository" "$(bytes "$uniq")"
  row "took" "$(duration "$dur")"
}

# The manual and scheduled paths deliberately run the same unit. Two entry
# points would mean two chunk caches and two things to keep in step.
cmd_now() {
  local verbose=false
  case "${1:-}" in
    -v | --verbose) verbose=true ;;
    "") ;;
    *) die "unknown option: $1" ;;
  esac

  if systemctl is-active --quiet "$BACKUP_UNIT"; then
    die "a backup is already running; watch it with: journalctl -fu $BACKUP_UNIT"
  fi

  sudo -v || die "need sudo to start $BACKUP_UNIT"

  # --wait blocks until the unit deactivates. Without it this returns as soon
  # as borg is forked, because the unit is Type=simple, and the result read
  # below would belong to the previous run rather than this one.
  if [[ "$verbose" == true ]]; then
    sudo journalctl -fu "$BACKUP_UNIT" -n 0 &
    follower=$!
    # shellcheck disable=SC2064
    trap "kill $follower 2>/dev/null || true" EXIT

    sudo systemctl start --wait "$BACKUP_UNIT" || true

    sleep 1
    kill "$follower" 2>/dev/null || true
    trap - EXIT
  else
    spin "Backing up to the NAS…" sudo systemctl start --wait "$BACKUP_UNIT" || true
  fi

  local result
  result=$(systemctl show "$BACKUP_UNIT" --property=Result --value)
  case "$result" in
    success) ;;
    exec-condition)
      warn "Skipped: the NAS was unreachable. The daily timer will catch up."
      return 0
      ;;
    *)
      journalctl -u "$BACKUP_UNIT" -n 15 --no-pager >&2
      die "the job failed with result: $result"
      ;;
  esac

  summarise_latest
}

cmd_status() {
  local next timer_state json count newest when age info uniq=""

  timer_state=$(systemctl is-active "${BACKUP_UNIT%.service}.timer" || true)
  next=$(systemctl show "${BACKUP_UNIT%.service}.timer" \
    --property=NextElapseUSecRealtime --value)

  # A running job has no exit timestamp yet, and the result it reports is
  # left over from the run before it. Reporting either would be a lie.
  if systemctl is-active --quiet "$BACKUP_UNIT"; then
    row "last run" "in progress since $(
      systemctl show "$BACKUP_UNIT" --property=ExecMainStartTimestamp --value
    )"
  else
    row "last run" "$(
      systemctl show "$BACKUP_UNIT" --property=ExecMainExitTimestamp --value
    ) ($(systemctl show "$BACKUP_UNIT" --property=Result --value))"
  fi

  row "next run" "${next:-unscheduled}"

  # status is the command you reach for when something is wrong, so it reports
  # the failure and carries on rather than aborting on it.
  local err
  err=$(mktemp)
  if ! json=$("$BACKUP_BORG" list --json 2>"$err"); then
    warn "The repository could not be read. borg said:"
    sed 's/^/  /' "$err" >&2
    rm -f "$err"
    return 0
  fi
  rm -f "$err"

  read -r count newest when <<<"$(
    printf '%s' "$json" | jq -r '
      [ (.archives | length | tostring),
        .archives[-1].name,
        .archives[-1].start
      ] | @tsv'
  )"

  # A second round trip that can fail on its own, and for the same reason as
  # the listing above it must not take the rest of the report down with it.
  err=$(mktemp)
  if info=$("$BACKUP_BORG" info --json --last 1 2>"$err"); then
    uniq=$(printf '%s' "$info" | jq -r '.cache.stats.unique_csize')
  else
    warn "The repository size could not be read. borg said:"
    sed 's/^/  /' "$err" >&2
  fi
  rm -f "$err"

  # An empty repository leaves the newest start time empty, which date reads as
  # today, so an age would be reported for a backup that was never taken.
  if [[ -n "$when" ]]; then
    age=$((($(date +%s) - $(date -d "${when%.*}" +%s)) / 86400))
    row "newest" "$newest"
    row "age" "$age day(s)"
  else
    row "newest" "none"
  fi
  row "archives" "$count"
  [[ -z "$uniq" ]] || row "repository" "$(bytes "$uniq")"

  [[ "$timer_state" == "active" ]] \
    || warn "The daily timer is $timer_state; scheduled backups are not running."

  if [[ -z "$when" ]]; then
    warn "The repository holds no archives; nothing has ever been backed up."
  else
    ((age < 3)) || warn "The newest archive is $age days old."
  fi

  # Append-only means nothing on this machine can trim the repository, so the
  # reminder has to come from somewhere.
  ((count < 60)) || warn "$count archives. Time to prune with the admin key; see BACKUPS.md."
}

cmd_list() {
  local json

  if [[ $# -gt 0 ]]; then
    "$BACKUP_BORG" list "::$1"
    return
  fi

  json=$(repo_json list --json)
  printf '%s' "$json" | jq -r '
    .archives | to_entries | reverse | .[] |
    "\(.key + 1)\t\(.value.name)\t\(.value.start | .[0:16] | sub("T"; " "))"' \
    | while IFS=$'\t' read -r i name start; do
      printf '  %s%3s%s  %-34s %s%s%s\n' \
        "$C_DIM" "$i" "$C_OFF" "$name" "$C_DIM" "$start" "$C_OFF"
    done
}

# Restoring is the one command here that destroys work, so the archive is
# always chosen deliberately rather than defaulted to. Newest is first in the
# list, which makes the common case one keystroke without making it automatic.
pick_archive() {
  local json chosen

  has_tui \
    || die "no terminal to choose an archive in; name one with --archive NAME"

  json=$(repo_json list --json --last 50)
  chosen=$(
    printf '%s' "$json" | jq -r '
      .archives | reverse | .[] |
      "\(.name)   \(.start | .[0:16] | sub("T"; " "))"' \
      | gum choose --height 12 --header "Restore from which archive?"
  ) || die "cancelled"

  printf '%s\n' "${chosen%% *}"
}

helium_running() {
  pgrep -x helium >/dev/null 2>&1 || [[ -e "$HELIUM_PROFILE/SingletonLock" ]]
}

# Only a restore that writes into the profile can damage a running browser, so
# that is the whole tree, or a named path inside it. Paths arrive here with the
# leading slash already stripped, the way the archive stores them.
restore_touches_helium() {
  (($# == 0)) && return 0

  local profile="${HELIUM_PROFILE#/}" path
  for path in "$@"; do
    [[ "$path" == "$profile" || "$path" == "$profile"/* ]] && return 0
  done
  return 1
}

# Archives store paths with the leading slash stripped, and borg extracts
# relative to the working directory. Restoring from anywhere but / quietly
# builds a nested copy of the tree instead of putting anything back.
cmd_restore() {
  local archive="" force=false
  local -a paths=()

  # Every positional is a path. The archive comes from the picker, or from
  # --archive when there is nobody at the keyboard to answer it.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true ;;
      --archive)
        shift
        [[ $# -gt 0 ]] || die "--archive needs an archive name"
        archive="$1"
        ;;
      -*) die "unknown option: $1" ;;
      *) paths+=("${1#/}") ;;
    esac
    shift
  done

  [[ -n "$archive" ]] || archive=$(pick_archive)

  if [[ "$force" != true ]] && restore_touches_helium "${paths[@]}" && helium_running; then
    die "Helium is running; close it first, or pass --force to overwrite a live profile"
  fi

  if [[ ${#paths[@]} -eq 0 ]]; then
    warn "About to restore the whole of $archive over the live filesystem."
  else
    warn "About to restore from $archive:"
    printf '  /%s\n' "${paths[@]}"
  fi

  # gum pre-selects the affirmative, and this is the one prompt in the program
  # where a stray Enter overwrites live files.
  gum confirm --default=false \
    "Overwrite existing files with the archived versions?" \
    || die "cancelled"

  # Ownership is restored by name rather than by number, so a rebuilt machine
  # gets the right owner even if the numeric id moved.
  cd / || die "cannot change to /"
  sudo --preserve-env=BORG_REPO,BORG_PASSCOMMAND,BORG_RSH \
    "$BACKUP_BORG" extract --progress "::$archive" "${paths[@]}"

  ok "Restored from $archive"
}

cmd_mount() {
  mkdir -p "$MOUNTPOINT"

  if [[ -n "${1:-}" ]]; then
    "$BACKUP_BORG" mount "::$1" "$MOUNTPOINT" || die "mount failed"
    ok "Mounted $1 at $MOUNTPOINT"
  else
    # The whole repository, so every archive is browsable side by side. This
    # is what replaces reaching for a GUI restore tool.
    "$BACKUP_BORG" mount "$BORG_REPO" "$MOUNTPOINT" || die "mount failed"
    ok "Mounted every archive at $MOUNTPOINT"
  fi

  printf '  %sunmount with: backup umount%s\n' "$C_DIM" "$C_OFF"
}

cmd_umount() {
  [[ -d "$MOUNTPOINT" ]] || die "nothing mounted at $MOUNTPOINT"
  "$BACKUP_BORG" umount "$MOUNTPOINT"
  rmdir "$MOUNTPOINT" 2>/dev/null || true
  ok "Unmounted"
}

# --repair is not offered on purpose: the server rejects it from this key, and
# reaching for it is nearly always the wrong move on a repository that still
# has a good copy somewhere.
cmd_check() {
  local -a args=(check --progress)
  [[ "${1:-}" == "--data" ]] && args+=(--verify-data)

  if "$BACKUP_BORG" "${args[@]}"; then
    ok "Repository is intact"
  else
    die "check reported problems; do not prune until they are understood"
  fi
}

case "${1:-}" in
  now)
    shift
    cmd_now "$@"
    ;;
  status)
    shift
    cmd_status "$@"
    ;;
  list)
    shift
    cmd_list "$@"
    ;;
  restore)
    shift
    cmd_restore "$@"
    ;;
  mount)
    shift
    cmd_mount "$@"
    ;;
  umount)
    shift
    cmd_umount "$@"
    ;;
  check)
    shift
    cmd_check "$@"
    ;;
  -h | --help | help | "") usage ;;
  *)
    printf 'backup: unknown command: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac
