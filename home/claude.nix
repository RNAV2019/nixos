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

  # Rate-limit percentages for the bar widget. Reads the OAuth token Claude Code
  # already stores; the token is only refreshed by Claude Code itself, so an
  # expired one is reported as a distinct `expired` state rather than burning a
  # request. The last good reading is cached so a failed poll degrades to a
  # stale value instead of blanking the bar.
  usage = pkgs.writeShellApplication {
    name = "claude-usage";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.coreutils];
    text = ''
      creds="$HOME/.claude/.credentials.json"
      cache="''${XDG_RUNTIME_DIR:-/tmp}/claude-usage.json"

      # Re-emit the last good reading tagged with $1, so a failed poll keeps a
      # number on the bar. Exit $2 when there has never been one to show.
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
          # Qt cannot parse the microsecond precision the API returns, so
          # reset times go out as epoch seconds.
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

  # Claude Code rewrites settings.json itself (/model, /config, plugin toggles),
  # so it is installed as a writable copy rather than a store symlink. Runtime
  # edits survive until the next rebuild, when the values above win again.
  home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm600 ${settingsFile} ${config.home.homeDirectory}/.claude/settings.json
  '';
}
