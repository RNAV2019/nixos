# Desktop helpers, started on Hyprland's first frame. Hyprland is already locked by then
# (--locked-cmd, see modules/system/session.nix).
{
  writeShellApplication,
  awww,
  cliphist,
  coreutils,
  wl-clipboard,
}:
writeShellApplication {
  name = "start-desktop";
  runtimeInputs = [awww cliphist coreutils wl-clipboard];
  text = builtins.readFile ./start-desktop.sh;
}
