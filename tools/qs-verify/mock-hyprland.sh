#!/usr/bin/env bash
# mock-hyprland.sh DATA_DIR — answer one Hyprland IPC request on stdin (socat runs it per connection).
# Only what the Displays view needs: the monitors from DATA_DIR/monitors.json, nothing else.
data=$1
req=$(dd bs=4096 count=1 2>/dev/null)
echo "$req" >>"$data/requests.log"
case $req in
  j/monitors*) cat "$data/monitors.json" ;;
  j/workspaces* | j/clients* | j/layers* | j/binds*) echo '[]' ;;
  *) echo '{}' ;;
esac
