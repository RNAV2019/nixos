{
  config,
  lib,
  pkgs,
  ...
}: let
  home = "/home/ryan";
  nasHost = "backup.ryannavsaria.co.uk";

  # Set to the NAS's address on your own network, as host:port, to bypass the
  # tunnel for the one-time seed of the first archive, then set it back to
  # null. Going through Cloudflare sends the first few gigabytes up your home
  # link and straight back down it again; on the LAN the same run takes
  # minutes. Borg identifies a repository by its id rather than its URL, so
  # switching back afterwards costs nothing and the chunk cache stays warm.
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

  # Taken from `docker exec borgserver cat /sshkeys/host/ssh_host_ed25519_key.pub`
  # once the container has started for the first time. While it is empty the
  # SSH connection falls back to trust-on-first-use, which is tolerable for the
  # LAN seed and must not survive it: with the repository reachable from the
  # internet, an unpinned host key is the whole of the authentication story on
  # the server's side.
  # The trailing comment on the generated key names the container id, which
  # changes whenever the container is recreated. The key itself lives in the
  # sshkeys volume and survives, so only the key material is recorded here.
  nasHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVKEhuXeZ9Tj737g1wLPHSePp+Mg9PglbZUSTyiZVyx";

  hostKeyPinned = nasHostKey != "";

  # Opens the tunnel and hands ssh a bidirectional stream on stdio. The service
  # token goes in through the environment rather than as a flag, because flags
  # are readable by any process that can run `ps`.
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

  # borg splits BORG_RSH with shell quoting rules, so every element here has to
  # survive as its own word. The proxy is a store path and cannot contain
  # spaces, which is what lets the -o argument go through unquoted.
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

  # Cheap liveness probe used as the timer's precondition. Closing stdin makes
  # the forced `borg serve` on the far end exit on its own, so this costs one
  # tunnel handshake and nothing else.
  #
  # Only a transport failure counts as unreachable. ssh reports every
  # connection-side error as 255, so the exit status on its own cannot tell a
  # NAS that is out of reach from one that is refusing us, and ssh's message is
  # the only thing that can. A rejected Cloudflare service token, a rotated or
  # revoked borg key, and a host key that no longer matches the pinned one are
  # all faults that have to be fixed rather than waited out; skipping on those
  # would leave the timer quietly declining to back anything up for as long as
  # the fault lasted. Those are therefore reported as reachable, with ssh's own
  # message left in the journal, so that the job runs and fails loudly.
  # Everything else — a closed tunnel, a timeout, a refused or reset
  # connection — is the transient case the condition exists for, and still
  # skips silently.
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
  # The tunnel name and the LAN address reach the same container, and so the
  # same host key, but ssh keys known_hosts by the name it was given. Both are
  # declared so that the seed is checked as strictly as everything after it.
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

      # Shell history and directory frecency. Small, and the difference
      # between a restored machine and one that only looks restored.
      "${home}/.local/share/atuin"
      "${home}/.local/share/zoxide"
    ];

    exclude = [
      # Build output. Cargo tags its own directories and --exclude-caches
      # below catches those; these are the ones that do not self-identify.
      "sh:${home}/Projects/**/node_modules"
      "sh:${home}/Work/**/node_modules"
      "sh:${home}/**/.direnv"
      "sh:${home}/**/.venv"
      "sh:${home}/**/__pycache__"

      # Rewritten by home/claude.nix on every rebuild, so backing it up only
      # creates a conflict on restore. .credentials.json is deliberately kept:
      # it is what makes Claude Code come back logged in.
      "${home}/.claude/settings.json"

      # Re-downloadable, and large.
      "${home}/.claude/cache"
      "${home}/.claude/plugins"
      "${home}/.claude/shell-snapshots"
      "${home}/.claude/telemetry"

      # Helium. Cookies, history, bookmarks and extension state are kept; this
      # machine runs no keyring, so Chromium's basic password store encrypts
      # them under a build-time constant and they decrypt on any machine.
      # Enabling gnome-keyring or kwallet later would silently end that.
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
      # The key lives in the repository, wrapped by the passphrase, so the
      # passphrase alone is enough to restore. That is what keeps the recovery
      # flow down to the age key plus Bitwarden.
      mode = "repokey-blake2";
      passCommand = "cat ${secret "borg/passphrase"}";
    };

    environment.BORG_RSH = borgRsh;

    # borg exits 1 when a file changed size or vanished while it was being
    # read, and the set above is full of files that do exactly that: a running
    # browser profile, atuin's database, which is written on every shell
    # command, and Downloads. With the nixpkgs default the archive is written
    # correctly and the unit is still marked failed, which trains the eye to
    # ignore a red `backup status`. A real error exits 2 and still fails.
    failOnWarnings = false;

    # The nixpkgs module reads this as "run `borg list`, and create the
    # repository if that fails for any reason at all". The precondition above
    # only proves the transport works, so a repository that is unreadable
    # rather than absent — a renamed or mistyped path, a `./backup` volume
    # restored empty — would be answered by silently initialising a fresh
    # empty one and backing into it, leaving `backup status` showing a single
    # healthy archive with the real history nowhere in sight. The repository is
    # created once, by hand, during the LAN seed; see BACKUPS.md.
    doInit = false;

    compression = "auto,zstd";
    startAt = "daily";
    persistentTimer = true;
    extraCreateArgs = ["--stats" "--exclude-caches"];

    # No prune. The server refuses it from this key by design, and retention
    # is an admin-key operation run by hand; see BACKUPS.md.
  };

  # A laptop is asleep or elsewhere often enough that an unreachable NAS is
  # normal rather than exceptional. Skipping keeps the unit out of the failed
  # list; the persistent timer catches up at the next opportunity.
  systemd.services.borgbackup-job-nas.serviceConfig.ExecCondition =
    lib.getExe nasReachable;

  # Nothing depends on backups landing at exactly midnight, and every machine
  # on a default timer waking together is how home links get saturated.
  systemd.timers.borgbackup-job-nas.timerConfig.RandomizedDelaySec = "30m";

  environment.systemPackages = [backup];
}
