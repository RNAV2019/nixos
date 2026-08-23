{
  config,
  lib,
  pkgs,
  ...
}: let
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [pkgs.git pkgs.jq];
    text = builtins.readFile ./claude-statusline.sh;
  };

  settings = {
    model = "opus";
    theme = "dark";
    effortLevel = "medium";
    tui = "fullscreen";
    autoCompactEnabled = true;
    agentPushNotifEnabled = true;
    skipDangerousModePermissionPrompt = true;

    env.CLAUDE_CODE_MAX_OUTPUT_TOKENS = "96000";

    statusLine = {
      type = "command";
      command = "${statusline}/bin/claude-statusline";
      padding = 0;
    };

    enabledPlugins = {
      "frontend-design@claude-plugins-official" = true;
      "ui-ux-pro-max@ui-ux-pro-max-skill" = true;
      "superpowers@claude-plugins-official" = true;
      "chrome-devtools-mcp@claude-plugins-official" = true;
      "figma@claude-plugins-official" = false;
    };

    extraKnownMarketplaces."ui-ux-pro-max-skill".source = {
      source = "github";
      repo = "nextlevelbuilder/ui-ux-pro-max-skill";
    };
  };

  settingsFile = (pkgs.formats.json {}).generate "claude-settings.json" settings;
in {
  home.packages = [statusline];

  # Claude Code rewrites settings.json itself (/model, /config, plugin toggles),
  # so it is installed as a writable copy rather than a store symlink. Runtime
  # edits survive until the next rebuild, when the values above win again.
  home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm600 ${settingsFile} ${config.home.homeDirectory}/.claude/settings.json
  '';
}
