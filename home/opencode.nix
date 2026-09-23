{
  config,
  lib,
  pkgs,
  ...
}: let
  # The Penpot MCP URL embeds a token, so it's merged from sops at activation
  # rather than baked into the store, like claude.nix.
  mcpMerge = pkgs.writeShellApplication {
    name = "opencode-mcp-merge";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    text = ''
      name="$1"
      url_file="$2"
      config="$HOME/.config/opencode/opencode.jsonc"

      # On first boot sops may not have decrypted it yet; don't fail activation.
      if [ ! -r "$url_file" ]; then
        echo "opencode-mcp-merge: $url_file not readable, skipping $name" >&2
        exit 0
      fi

      tmp=$(mktemp "$config.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      jq --arg name "$name" --rawfile url "$url_file" \
        '.mcp[$name] = {type: "remote", url: ($url | rtrimstr("\n")), enabled: true}' \
        "$config" > "$tmp"
      chmod 600 "$tmp"
      mv -f "$tmp" "$config"
    '';
  };

  settings = {
    "$schema" = "https://opencode.ai/config.json";
    plugin = ["@prevalentware/opencode-goal-plugin"];
  };

  settingsFile = (pkgs.formats.json {}).generate "opencode-config.json" settings;
in {
  # A writable copy, since opencode installs plugin deps next to it at runtime.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm600 ${settingsFile} ${config.home.homeDirectory}/.config/opencode/opencode.jsonc
  '';

  home.activation.opencodeMcpServers = lib.hm.dag.entryAfter ["opencodeSettings"] ''
    run ${mcpMerge}/bin/opencode-mcp-merge penpot \
      ${config.home.homeDirectory}/.config/claude/penpot-mcp-url
  '';
}
