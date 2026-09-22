{
  config,
  lib,
  pkgs,
  ...
}: let
  home = "/home/ryan";

  # `sudo edit-secrets [FILE]` opens secrets/FILE (default secrets.yaml) in sops.
  # A command, not an alias, since sudo can't see fish aliases and drops EDITOR.
  edit-secrets = pkgs.writeShellApplication {
    name = "edit-secrets";
    runtimeInputs = [pkgs.sops pkgs.coreutils];
    text = ''
      if [[ $EUID -ne 0 ]]; then
        echo "edit-secrets: the age key is root-only; run: sudo edit-secrets" >&2
        exit 1
      fi

      file="${home}/nixos/secrets/''${1:-secrets.yaml}"
      [[ -f "$file" ]] || { echo "edit-secrets: no such file: $file" >&2; exit 1; }

      export SOPS_AGE_KEY_FILE=${config.sops.age.keyFile}
      export EDITOR=${lib.getExe config.home-manager.users.ryan.programs.helix.package}

      # sops exits non-zero when nothing changed; hand the file back to ryan either way.
      rc=0
      sops "$file" || rc=$?
      chown ryan:users "$file"
      exit "$rc"
    '';
  };

  # Secrets are read-only symlinks into /run/secrets.d, so programs that rewrite
  # their own config (gh auth login, opencode) must be updated via secrets.yaml.
  owned = {
    owner = "ryan";
    group = "users";
    mode = "0400";
  };
  ownedAt = path: owned // {inherit path;};
in {
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Restored by hand from Bitwarden on new hardware; see README.
    age = {
      keyFile = "/etc/nixos-secrets/age.key";
      generateKey = false;
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];

    secrets = {
      # gen-commit reads this exact path; see home/gen-commit.sh.
      "openrouter/gen-commit-key" = ownedAt "${home}/.config/gen-commit/api-key";
      "cloudflared/cert" = ownedAt "${home}/.cloudflared/cert.pem";
      # cloudflared names this file after the tunnel UUID.
      "cloudflared/tunnel-credentials" =
        ownedAt "${home}/.cloudflared/ea0861b0-1304-4833-9fa8-504167927194.json";

      # Decrypted before users are created; stays root-owned under /run/secrets-for-users.
      "users/ryan-hashed-password".neededForUsers = true;

      # Merged into ~/.claude.json by home/claude.nix; the URL carries the Penpot token.
      "penpot/mcp-url" = ownedAt "${home}/.config/claude/penpot-mcp-url";

      # Secret Google Calendar iCal URLs, one per line; see home/ical-agenda.nix.
      "calendar/ical-urls" = ownedAt "${home}/.config/quickshell-calendar/ical-urls";

      # Consumed by the templates below rather than by a program directly.
      "gh/token" = owned;
      "openrouter/opencode-key" = owned;
      "opencode/go-key" = owned;

      # Owned by ryan so reading an archive needs no sudo; the backup job runs as root.
      "borg/passphrase" = owned;
      "borg/ssh-key" = owned;

      # Cloudflare Access guards the tunnel hostname in front of SSH.
      "cloudflare/access-token-id" = owned;
      "cloudflare/access-token-secret" = owned;
    };

    templates = {
      "gh-hosts.yml" =
        owned
        // {
          path = "${home}/.config/gh/hosts.yml";
          # https because this machine has no SSH key yet.
          content = ''
            github.com:
                users:
                    RNAV2019:
                        oauth_token: ${config.sops.placeholder."gh/token"}
                git_protocol: https
                oauth_token: ${config.sops.placeholder."gh/token"}
                user: RNAV2019
          '';
        };

      "opencode-auth.json" =
        owned
        // {
          path = "${home}/.local/share/opencode/auth.json";
          content = ''
            {"openrouter":{"type":"api","key":"${config.sops.placeholder."openrouter/opencode-key"}"},"opencode-go":{"type":"api","key":"${config.sops.placeholder."opencode/go-key"}"}}
          '';
        };
    };
  };

  # Create parent dirs as ryan before sops-nix would create them as root.
  system.activationScripts.userSecretDirs = {
    deps = ["users" "groups"];
    text = ''
      for dir in \
        ${home}/.config/gh \
        ${home}/.config/gen-commit \
        ${home}/.config/claude \
        ${home}/.config/quickshell-calendar \
        ${home}/.cloudflared \
        ${home}/.local/share/opencode; do
        install -d -o ryan -g users -m 0700 "$dir"
      done
    '';
  };
  system.activationScripts.setupSecrets.deps = ["userSecretDirs"];

  environment.systemPackages = [edit-secrets];
}
