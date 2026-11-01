#!/usr/bin/env bash
# restart.sh — quit the harness's quickshell and start it again on the same scratch HOME, buses and
# compositor, so what the shell keeps in ~/.local/state is read back as it is after a real restart.
# Waits for ipc as run.sh does.
#
#   QS_VERIFY_WORK=/tmp/x restart.sh
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
scrub_live_env
load_env

pkill -f -- "quickshell --no-color -p $QSV_CFG" || true
for _ in $(seq 50); do
  pgrep -f -- "quickshell --no-color -p $QSV_CFG" >/dev/null || break
  sleep 0.1
done
pgrep -f -- "quickshell --no-color -p $QSV_CFG" >/dev/null && die "quickshell did not quit"

echo "--- restart $(date -u +%T) ---" >>"$QSV_WORK/quickshell.log"
start_shell || die "quickshell never answered ipc after the restart"
# As run.sh: singletons start on first use and the OSD ignores signals for its first dwell.
sleep 4
echo "qs-verify: restarted (work $QSV_WORK)"
