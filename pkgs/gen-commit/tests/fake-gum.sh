#!/usr/bin/env bash
set -euo pipefail

pop_queue() {
  local queue=$1 response index
  local -a entries=()

  if [[ -f "$queue" ]]; then
    mapfile -t entries < "$queue"
  fi
  response=${entries[0]:-__CANCEL__}
  : > "$queue"
  for ((index = 1; index < ${#entries[@]}; index++)); do
    printf '%s\n' "${entries[$index]}" >> "$queue"
  done
  printf '%s' "$response"
}

command=${1:?gum command is required}
shift

case "$command" in
  style)
    printf '%s\n' "${*: -1}"
    ;;
  join)
    after_separator=false
    for argument in "$@"; do
      if [[ "$argument" == -- ]]; then
        after_separator=true
        continue
      fi
      if [[ "$after_separator" == false && "$argument" == --* ]]; then
        continue
      fi
      printf '%s\n' "$argument"
    done
    ;;
  spin)
    while (($# > 0)) && [[ "$1" != -- ]]; do
      shift
    done
    [[ ${1:-} == -- ]] && shift
    "$@"
    ;;
  choose)
    response=$(pop_queue "${GUM_CHOOSE_QUEUE:?GUM_CHOOSE_QUEUE is required}")
    if [[ "$response" == __CANCEL__ ]]; then
      exit 130
    fi
    valid=false
    for argument in "$@"; do
      if [[ "$argument" == "$response" ]]; then
        valid=true
        break
      fi
    done
    if [[ "$valid" == false ]]; then
      printf 'fake gum choice was not offered: %s\n' "$response" >&2
      exit 2
    fi
    if [[ "$response" == Commit && -n "${GUM_BEFORE_COMMIT_HOOK:-}" ]]; then
      bash "$GUM_BEFORE_COMMIT_HOOK"
    fi
    printf '%s\n' "$response"
    ;;
  write)
    response=$(pop_queue "${GUM_WRITE_QUEUE:?GUM_WRITE_QUEUE is required}")
    case "$response" in
      __CANCEL__)
        exit 130
        ;;
      __EMPTY__)
        exit 0
        ;;
      *)
        printf '%s\n' "$response"
        ;;
    esac
    ;;
  *)
    printf 'unsupported fake gum command: %s\n' "$command" >&2
    exit 2
    ;;
esac
