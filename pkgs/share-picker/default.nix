# The picker xdph runs for a screen-share request (screencopy:custom_picker_binary).
{
  writeShellApplication,
  coreutils,
  hyprland,
  jq,
  quickshell,
  slurp,
  xdg-desktop-portal-hyprland,
}:
writeShellApplication {
  name = "share-picker";
  runtimeInputs = [coreutils hyprland jq quickshell slurp];
  # The stock Qt picker is the way out whenever the shell cannot answer.
  text = ''
    stock=${xdg-desktop-portal-hyprland}/bin/hyprland-share-picker
    ${builtins.readFile ./share-picker.sh}
  '';
}
