{
  config,
  lib,
  ...
}: {
  options.desktop.monitors = lib.mkOption {
    type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
    default = [];
    description = ''
      Hyprland monitor rules for this host's own outputs, set in
      hosts/<name>/default.nix. They come ahead of a catch-all that lights up
      any other output at its preferred mode.
    '';
  };

  # The host rules come first so they win, then a catch-all lights up any
  # output the host has never seen.
  config.wayland.windowManager.hyprland.settings.monitor =
    config.desktop.monitors
    ++ [
      {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = 1.0;
      }
    ];
}
