{
  config,
  lib,
  pkgs,
  ...
}: let
  settings = {
    "$schema" = "https://opencode.ai/config.json";
    plugin = ["@prevalentware/opencode-goal-plugin"];
  };

  settingsFile = (pkgs.formats.json {}).generate "opencode-config.json" settings;
in {
  # opencode installs plugin deps into node_modules next to this file at
  # runtime, so it must stay a writable copy rather than a store symlink.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm600 ${settingsFile} ${config.home.homeDirectory}/.config/opencode/opencode.jsonc
  '';
}
