#!/usr/bin/env bash
set -euo pipefail

if [[ "${EDITOR_FAIL:-false}" == true ]]; then
  exit 1
fi

printf '%b\n' "${EDITOR_MESSAGE:?EDITOR_MESSAGE is required}" > "${*: -1}"
if [[ -n "${EDITOR_CALLS_FILE:-}" ]]; then
  printf 'called\n' >> "$EDITOR_CALLS_FILE"
fi
