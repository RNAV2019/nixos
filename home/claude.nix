{
  config,
  lib,
  pkgs,
  ...
}: let
  # User-scope MCP servers only live in ~/.claude.json, which is also Claude
  # Code's mutable state, so entries are merged into it rather than generated.
  mcpMerge = pkgs.writeShellApplication {
    name = "claude-mcp-merge";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    text = ''
      name="$1"
      url_file="$2"
      config="$HOME/.claude.json"

      # On first boot sops may not have decrypted it yet; don't fail activation.
      if [ ! -r "$url_file" ]; then
        echo "claude-mcp-merge: $url_file not readable, skipping $name" >&2
        exit 0
      fi

      [ -e "$config" ] || echo '{}' > "$config"

      tmp=$(mktemp "$config.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      jq --arg name "$name" --rawfile url "$url_file" \
        '.mcpServers[$name] = {type: "http", url: ($url | rtrimstr("\n"))}' \
        "$config" > "$tmp"
      chmod 600 "$tmp"
      mv -f "$tmp" "$config"
    '';
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
      command = lib.getExe pkgs.claude-statusline;
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
  home.packages = [pkgs.claude-statusline pkgs.claude-usage];

  # A writable copy, since Claude Code edits settings.json itself; rebuilds reset it.
  home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm600 ${settingsFile} ${config.home.homeDirectory}/.claude/settings.json
  '';

  # The URL embeds the Penpot token; see modules/system/secrets.nix.
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${mcpMerge}/bin/claude-mcp-merge penpot \
      ${config.home.homeDirectory}/.config/claude/penpot-mcp-url
  '';
}
