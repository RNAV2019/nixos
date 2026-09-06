{
  config,
  lib,
  pkgs,
  ...
}: let
  # Remote MCP servers live in the same config file, but the Penpot URL
  # carries its user token in the query string, so it cannot be baked into
  # the store path; it is merged in from sops at activation, like claude.nix.
  mcpMerge = pkgs.writeShellApplication {
    name = "opencode-mcp-merge";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    text = ''
      name="$1"
      url_file="$2"
      config="$HOME/.config/opencode/opencode.jsonc"

      # The URL arrives from sops, which decrypts after this on a fresh
      # machine's first boot. Skip rather than fail the whole activation.
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
  # opencode installs plugin deps into node_modules next to this file at
  # runtime, so it must stay a writable copy rather than a store symlink.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm600 ${settingsFile} ${config.home.homeDirectory}/.config/opencode/opencode.jsonc
  '';

  # The Penpot user token is the URL's query string, so the whole URL is a
  # secret; see modules/system/secrets.nix for the path.
  home.activation.opencodeMcpServers = lib.hm.dag.entryAfter ["opencodeSettings"] ''
    run ${mcpMerge}/bin/opencode-mcp-merge penpot \
      ${config.home.homeDirectory}/.config/claude/penpot-mcp-url
  '';
}
