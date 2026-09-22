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

  # Rate-limit percentages for the bar, via Claude Code's stored OAuth token.
  # Expired tokens report `expired`; failed polls fall back to the cached reading.
  usage = pkgs.writeShellApplication {
    name = "claude-usage";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.coreutils];
    text = ''
      creds="$HOME/.claude/.credentials.json"
      cache="''${XDG_RUNTIME_DIR:-/tmp}/claude-usage.json"

      # Re-emit the cached reading with status $1, or exit $2 if there is none.
      emit_cached() {
        if [ -r "$cache" ]; then
          jq -ce --arg s "$1" '.status = $s' "$cache" && exit 0
        fi
        exit "$2"
      }

      [ -r "$creds" ] || emit_cached expired 2

      expires=$(jq -r '.claudeAiOauth.expiresAt // 0' "$creds")
      [ "$expires" -gt "$(date +%s%3N)" ] || emit_cached expired 2

      token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds")
      [ -n "$token" ] || emit_cached expired 2

      body=$(mktemp)
      trap 'rm -f "$body"' EXIT

      code=$(curl -s --max-time 10 -o "$body" -w '%{http_code}' \
        https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20") || emit_cached stale 1

      case "$code" in
        200) ;;
        # The token outlived its expiresAt claim, or the session was revoked.
        401 | 403) emit_cached expired 2 ;;
        # Rate limited, 5xx, or a captive-portal style interception.
        *) emit_cached stale 1 ;;
      esac

      jq -ce '
          # Epoch seconds, since Qt can't parse the API's microseconds.
          def epoch: if . == null then 0 else sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | fromdateiso8601 end;
          {
            status: "ok",
            updated: (now | floor),
            fiveHour: (.five_hour.utilization // 0),
            sevenDay: (.seven_day.utilization // 0),
            fiveHourResets: (.five_hour.resets_at | epoch),
            sevenDayResets: (.seven_day.resets_at | epoch)
          }' < "$body" > "$cache.tmp" || emit_cached stale 1

      mv -f "$cache.tmp" "$cache"
      cat "$cache"
    '';
  };

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
  home.packages = [statusline usage];

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
