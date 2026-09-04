{config, ...}: let
  home = "/home/ryan";

  # Every secret here decrypts to a file owned by ryan. sops-nix writes the
  # real file under /run/secrets.d and leaves a symlink at `path`, so these
  # locations are read-only: a program that rewrites its own config (gh auth
  # login, opencode) fails against them, and the new value belongs in
  # secrets/secrets.yaml instead.
  owned = {
    owner = "ryan";
    group = "users";
    mode = "0400";
  };
  ownedAt = path: owned // {inherit path;};
in {
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Restored by hand from Bitwarden as the first step on new hardware; see
    # README. Nothing else can decrypt secrets/secrets.yaml.
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
      # cloudflared derives this filename from the tunnel UUID, and forward-dev
      # runs the tunnel by name, so it must keep the UUID it was issued under.
      "cloudflared/tunnel-credentials" =
        ownedAt "${home}/.cloudflared/ea0861b0-1304-4833-9fa8-504167927194.json";

      # Decrypted before users are created, so users.users.ryan can point at
      # it. neededForUsers secrets stay root-owned under
      # /run/secrets-for-users and take no owner or mode of their own.
      "users/ryan-hashed-password".neededForUsers = true;

      # Consumed by the templates below rather than by a program directly.
      "gh/token" = owned;
      "openrouter/opencode-key" = owned;
    };

    templates = {
      "gh-hosts.yml" =
        owned
        // {
          path = "${home}/.config/gh/hosts.yml";
          # git_protocol stays https: there is no SSH key on this machine yet,
          # despite the ssh default in home/dev.nix.
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
            {"openrouter":{"type":"api","key":"${config.sops.placeholder."openrouter/opencode-key"}"}}
          '';
        };
    };
  };

  # sops-nix creates missing parent directories as root, which would leave a
  # fresh machine unable to write anything else into them. Claim them first.
  system.activationScripts.userSecretDirs = {
    deps = ["users" "groups"];
    text = ''
      for dir in \
        ${home}/.config/gh \
        ${home}/.config/gen-commit \
        ${home}/.cloudflared \
        ${home}/.local/share/opencode; do
        install -d -o ryan -g users -m 0700 "$dir"
      done
    '';
  };
  system.activationScripts.setupSecrets.deps = ["userSecretDirs"];
}
