{
  config,
  lib,
  pkgs,
  ...
}: let
  home = "/home/ryan";
  nasHost = "backup.ryannavsaria.co.uk";

  # Set to the NAS's LAN host:port to seed the first archive without the tunnel,
  # then reset to null. Borg keys repos by id, so switching back is free.
  lanSeed = null; # e.g. "192.168.0.216:2222"

  seeding = lanSeed != null;

  # Only ever forced when seeding, so lanSeed being null is not a problem.
  lanParts = lib.splitString ":" (
    if seeding
    then lanSeed
    else ""
  );
  lanHost = lib.head lanParts;
  lanPort = lib.last lanParts;

  nasAddress =
    if seeding
    then lanSeed
    else nasHost;

  repo = "ssh://borg@${nasAddress}/backup/ryans-nixos/repo";

  secret = name: config.sops.secrets.${name}.path;

  # From `docker exec borgserver cat /sshkeys/host/ssh_host_ed25519_key.pub`,
  # minus its container-id comment. Empty means trust-on-first-use (LAN seed only).
  nasHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVKEhuXeZ9Tj737g1wLPHSePp+Mg9PglbZUSTyiZVyx";

  hostKeyPinned = nasHostKey != "";

  # ssh ProxyCommand through the tunnel. The token goes via env, not flags, to stay out of `ps`.
  nasProxy = pkgs.writeShellApplication {
    name = "borg-nas-proxy";
    runtimeInputs = [pkgs.cloudflared pkgs.coreutils];
    text = ''
      TUNNEL_SERVICE_TOKEN_ID=$(cat ${secret "cloudflare/access-token-id"})
      TUNNEL_SERVICE_TOKEN_SECRET=$(cat ${secret "cloudflare/access-token-secret"})
      export TUNNEL_SERVICE_TOKEN_ID TUNNEL_SERVICE_TOKEN_SECRET

      exec cloudflared access ssh --hostname ${nasHost}
    '';
  };

  # borg word-splits BORG_RSH, so no element may contain spaces.
  borgRsh = lib.concatStringsSep " " (
    [
      "ssh"
      "-i ${secret "borg/ssh-key"}"
      "-o BatchMode=yes"
      "-o StrictHostKeyChecking=${
        if hostKeyPinned
        then "yes"
        else "accept-new"
      }"
    ]
    ++ lib.optional (!seeding) "-o ProxyCommand=${nasProxy}/bin/borg-nas-proxy"
  );

  # Liveness probe gating the backup job; only transport failures skip it.
  # Auth and host-key errors report reachable so the job runs and fails loudly.
  nasReachable = pkgs.writeShellApplication {
    name = "borg-nas-reachable";
    runtimeInputs = [pkgs.openssh pkgs.gnugrep];
    text = ''
      rc=0
      err=$(${borgRsh} -o ConnectTimeout=30 \
        ${lib.optionalString seeding "-p ${lanPort} "}borg@${
        if seeding
        then lanHost
        else nasHost
      } \
        </dev/null 2>&1 >/dev/null) || rc=$?

      if [[ "$rc" -eq 255 ]]; then
        if grep -qiE 'permission denied|remote host identification has changed|host key verification failed|too many authentication failures|no matching host key' <<<"$err"; then
          printf '%s\n' "$err" >&2
          exit 0
        fi
        exit 1
      fi
      exit 0
    '';
  };

  backup = pkgs.writeShellApplication {
    name = "backup";
    runtimeInputs = [
      pkgs.borgbackup
      pkgs.coreutils
      pkgs.gum
      pkgs.procps
      pkgs.systemd
      pkgs.jq
    ];
    text =
      ''
        export BORG_REPO=${lib.escapeShellArg repo}
        export BORG_PASSCOMMAND=${lib.escapeShellArg "cat ${secret "borg/passphrase"}"}
        export BORG_RSH=${lib.escapeShellArg borgRsh}
        BACKUP_UNIT=borgbackup-job-nas.service
        BACKUP_BORG=${lib.getExe pkgs.borgbackup}
        export BACKUP_UNIT BACKUP_BORG
      ''
      + builtins.readFile ./backup.sh;
  };
in {
  # Pin the key under the LAN address too, so the seed is checked as strictly.
  programs.ssh.knownHosts = lib.optionalAttrs hostKeyPinned {
    borg-nas = {
      hostNames = [nasHost] ++ lib.optional seeding "[${lanHost}]:${lanPort}";
      publicKey = nasHostKey;
    };
  };

  services.borgbackup.jobs.nas = {
    inherit repo;
    archiveBaseName = "ryans-nixos";

    paths = [
      "${home}/Projects"
      "${home}/Work"
      "${home}/Documents"
      "${home}/resume"
      "${home}/Pictures"
      "${home}/Desktop"
      "${home}/Downloads"
      "${home}/Music"
      "${home}/Videos"
      "${home}/.claude"
      "${home}/.config/net.imput.helium"

      # Shell history and directory frecency.
      "${home}/.local/share/atuin"
      "${home}/.local/share/zoxide"
    ];

    exclude = [
      # Build output that isn't CACHEDIR.TAG-tagged like Cargo's.
      "sh:${home}/Projects/**/node_modules"
      "sh:${home}/Work/**/node_modules"
      "sh:${home}/**/.direnv"
      "sh:${home}/**/.venv"
      "sh:${home}/**/__pycache__"
      "sh:${home}/**/.next"
      "sh:${home}/**/.gradle"
      "sh:${home}/**/.kotlin"

      # Gradle's heavy build/ children; build/ itself can hold source.
      "sh:${home}/**/build/intermediates"
      "sh:${home}/**/build/outputs"
      "sh:${home}/**/build/reports"
      "sh:${home}/**/build/kspCaches"
      "sh:${home}/**/build/tmp"

      # Rewritten by home/claude.nix on every rebuild.
      "${home}/.claude/settings.json"

      # Re-downloadable, and large.
      "${home}/.claude/cache"
      "${home}/.claude/plugins"
      "${home}/.claude/shell-snapshots"
      "${home}/.claude/telemetry"

      # Helium caches. Profile data is kept and portable because no keyring is
      # running; enabling one would tie it to this machine.
      "sh:${home}/.config/net.imput.helium/*/Cache"
      "sh:${home}/.config/net.imput.helium/*/Code Cache"
      "sh:${home}/.config/net.imput.helium/*/GPUCache"
      "sh:${home}/.config/net.imput.helium/*/Service Worker/CacheStorage"
      "${home}/.config/net.imput.helium/component_crx_cache"
      "${home}/.config/net.imput.helium/extensions_crx_cache"
      "${home}/.config/net.imput.helium/GPUPersistentCache"
      "${home}/.config/net.imput.helium/Crash Reports"
      "sh:${home}/.config/net.imput.helium/BrowserMetrics*"

      # Sockets and lock files; borg would warn on every run.
      "sh:${home}/.config/net.imput.helium/Singleton*"
    ];

    encryption = {
      # Key stored in the repo, so the passphrase alone is enough to restore.
      mode = "repokey-blake2";
      passCommand = "cat ${secret "borg/passphrase"}";
    };

    environment.BORG_RSH = borgRsh;

    # Files changing mid-read (browser profile, atuin db) make borg exit 1 with
    # a good archive. Real errors exit 2 and still fail.
    failOnWarnings = false;

    # doInit would silently create a fresh repo whenever `borg list` fails, e.g. on
    # a mistyped path. The repo is created by hand during the LAN seed; see README.
    doInit = false;

    compression = "auto,zstd";
    startAt = "daily";
    persistentTimer = true;
    extraCreateArgs = ["--stats" "--exclude-caches"];

    # No prune: this key can't, by design. Retention is done by hand; see README.
  };

  # An unreachable NAS is normal on a laptop; skip rather than fail and let the
  # persistent timer catch up.
  systemd.services.borgbackup-job-nas.serviceConfig.ExecCondition =
    lib.getExe nasReachable;

  systemd.timers.borgbackup-job-nas.timerConfig.RandomizedDelaySec = "30m";

  environment.systemPackages = [backup];
}
