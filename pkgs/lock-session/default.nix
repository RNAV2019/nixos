# Start Quickshell if needed and wait until every output is locked.
{
  writeShellApplication,
  coreutils,
  hyprland,
  quickshell,
  systemd,
}:
writeShellApplication {
  name = "lock-session";
  runtimeInputs = [quickshell coreutils systemd hyprland];
  text = builtins.readFile ./lock-session.sh;
}
