# Lectern lecture-notes reader (~/Projects/lectern). Notes live in ~/Documents/gen-notes.
{repoDir, ...}: {
  programs.lectern = {
    enable = true;
    palettePath = "${repoDir}/home/quickshell/Commons/palettes.json";
    # Chromium draws through XWayland, which Hyprland leaves at native pixels
    # (xwayland.force_zero_scaling in desktop.nix); this is eDP-1's scale.
    uiScale = 1.3333333;
  };
}
