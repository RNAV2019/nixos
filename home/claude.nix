{
  config,
  lib,
  pkgs,
  ...
}: let
  # User-scope MCP servers only live in ~/.claude.json, which is also Claude
  # Code's mutable state, so entries are merged into it rather than generated.
  # Usage: claude-mcp-merge NAME ENTRY_JSON [URL_FILE]. With URL_FILE, its
  # contents become the entry's url (for URLs that embed a secret).
  mcpMerge = pkgs.writeShellApplication {
    name = "claude-mcp-merge";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    text = ''
      name="$1"
      entry="$2"
      url_file="''${3:-}"
      config="$HOME/.claude.json"

      # On first boot sops may not have decrypted it yet; don't fail activation.
      if [ -n "$url_file" ] && [ ! -r "$url_file" ]; then
        echo "claude-mcp-merge: $url_file not readable, skipping $name" >&2
        exit 0
      fi

      [ -e "$config" ] || echo '{}' > "$config"

      tmp=$(mktemp "$config.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      if [ -n "$url_file" ]; then
        jq --arg name "$name" --slurpfile entry "$entry" --rawfile url "$url_file" \
          '.mcpServers[$name] = ($entry[0] + {url: ($url | rtrimstr("\n"))})' \
          "$config" > "$tmp"
      else
        jq --arg name "$name" --slurpfile entry "$entry" \
          '.mcpServers[$name] = $entry[0]' \
          "$config" > "$tmp"
      fi
      chmod 600 "$tmp"
      mv -f "$tmp" "$config"
    '';
  };

  mcpEntry = name: entry: (pkgs.formats.json {}).generate "claude-mcp-${name}.json" entry;

  # OpenPencil's stdio bridge reaches the desktop app's own MCP server, so it
  # only answers while the app has a document open (pkgs/openpencil).
  openpencilMcp = mcpEntry "openpencil" {
    command = lib.getExe' pkgs.openpencil-cli "openpencil-mcp";
    env = {
      OPENPENCIL_MCP_ROOT = config.home.homeDirectory;
      OPENPENCIL_MCP_EVAL = "1";
    };
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

  # The Penpot URL embeds its token; see modules/system/secrets.nix.
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${mcpMerge}/bin/claude-mcp-merge penpot ${mcpEntry "penpot" {type = "http";}} \
      ${config.home.homeDirectory}/.config/claude/penpot-mcp-url
    run ${mcpMerge}/bin/claude-mcp-merge openpencil ${openpencilMcp}
  '';
}
