# Borg Backups

Laptop pushes to a `borg serve` container on the UGREEN DH4300 Plus over SSH.
The server runs append-only, so a compromised laptop cannot destroy history.
Both the SSH key and the repository passphrase come from sops-nix.

Replace `nas.lan` with the NAS hostname or IP throughout.

---

## 1. Generate the two keypairs

Two keys, because append-only means the backup key can never prune:

| Key | Lives | Can |
|---|---|---|
| `ryans-nixos` | sops-nix, on the laptop | create archives only |
| `borg-admin` | Bitwarden only | prune, delete, compact |

```sh
cd (mktemp -d)
ssh-keygen -t ed25519 -N "" -C "borg ryans-nixos" -f ryans-nixos
ssh-keygen -t ed25519 -N "" -C "borg admin"       -f borg-admin
openssl rand -base64 32   # repository passphrase
```

Put in Bitwarden now, before anything else: the passphrase, both private keys,
and a note pointing at this file. None of it is recoverable from the backup.

---

## 2. Bring up the server on the NAS

Create the layout and drop both public keys in. The filename becomes the
client directory name, and the daemon refuses to start with an empty
`clients/`.

```sh
mkdir -p /volume1/borg/sshkeys/clients /volume1/borg/backup
chown -R 1000:1000 /volume1/borg
# copy ryans-nixos.pub -> /volume1/borg/sshkeys/clients/ryans-nixos
# copy borg-admin.pub  -> /volume1/borg/sshkeys/clients/borg-admin
```

`docker-compose.yml`:

```yaml
services:
  borgserver:
    image: nold360/borgserver:trixie
    container_name: borgserver
    restart: unless-stopped
    ports:
      - "2222:22"
    volumes:
      - /volume1/borg/backup:/backup
      - /volume1/borg/sshkeys:/sshkeys
    environment:
      BORG_APPEND_ONLY: "yes"
      BORG_ADMIN: "borg-admin"
      PUID: "1000"
      PGID: "1000"
```

```sh
docker compose up -d
docker exec borgserver borg --version   # must be 1.4.x to match the laptop
```

The `trixie` tag carries borg 1.4; the `bookworm` tag carries 1.2 and will
warn on every run. Host keys are generated once into `sshkeys/host/` and
persist, which is what makes strict host-key checking below possible.

---

## 3. Load the secrets

```sh
cd ~/nixos
sops secrets/secrets.yaml
```

Add, with the private key as a literal block so newlines survive:

```yaml
borg:
    passphrase: <the openssl output>
    ssh-key: |
        -----BEGIN OPENSSH PRIVATE KEY-----
        ...
        -----END OPENSSH PRIVATE KEY-----
```

Then in `modules/system/secrets.nix`, alongside the existing entries. These
stay root-owned at their default `/run/secrets` paths, because the backup
service runs as root:

```nix
"borg/passphrase" = {};
"borg/ssh-key" = {mode = "0400";};
```

Delete the temporary directory from step 1 once this decrypts cleanly.

---

## 4. Pin the NAS host key

Without this the first non-interactive run hangs on an unknown host.

```sh
ssh-keyscan -p 2222 nas.lan
```

Into `modules/system/default.nix`:

```nix
programs.ssh.knownHosts."[nas.lan]:2222".publicKey = "ssh-ed25519 AAAA...";
```

---

## 5. Declare the job

New file `modules/system/backups.nix`, imported from `flake.nix` next to
`secrets.nix`:

```nix
{config, ...}: let
  home = "/home/ryan";
in {
  services.borgbackup.jobs.nas = {
    repo = "ssh://borg@nas.lan:2222/backup/ryans-nixos/repo";

    paths = [
      "${home}/Projects"
      "${home}/Work"
      "${home}/Documents"
      "${home}/resume"
      "${home}/Pictures"
      "${home}/.claude"
      "${home}/.config/net.imput.helium"
    ];

    exclude = [
      # Cargo and friends drop CACHEDIR.TAG in build dirs, which
      # --exclude-caches below already catches. These are the ones that
      # do not tag themselves.
      "sh:${home}/Projects/**/node_modules"
      "sh:${home}/Work/**/node_modules"
      "sh:${home}/**/.direnv"
      "sh:${home}/**/.venv"

      # Re-downloadable or per-machine.
      "${home}/.claude/cache"
      "${home}/.claude/plugins"
      "${home}/.claude/shell-snapshots"
      "${home}/.claude/telemetry"

      # Helium: keep history, bookmarks, cookies and extension state; drop
      # everything the browser rebuilds on its own.
      "sh:${home}/.config/net.imput.helium/*/Cache"
      "sh:${home}/.config/net.imput.helium/*/Code Cache"
      "sh:${home}/.config/net.imput.helium/*/GPUCache"
      "sh:${home}/.config/net.imput.helium/*/Service Worker/CacheStorage"
      "${home}/.config/net.imput.helium/component_crx_cache"
      "${home}/.config/net.imput.helium/extensions_crx_cache"
      "${home}/.config/net.imput.helium/GPUPersistentCache"
      "${home}/.config/net.imput.helium/Crash Reports"
      "${home}/.config/net.imput.helium/Singleton*"
    ];

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets."borg/passphrase".path}";
    };

    environment.BORG_RSH =
      "ssh -i ${config.sops.secrets."borg/ssh-key".path}";

    compression = "auto,zstd";
    startAt = "daily";
    persistentTimer = true;
    extraCreateArgs = ["--stats" "--exclude-caches"];

    # No prune here on purpose: the server is append-only and would reject
    # it. Retention is an admin-key operation, see below.
  };
}
```

`doInit` defaults to true, so the first run creates the repository. With
`repokey-blake2` the key material lives inside the repo, encrypted by the
passphrase, so the passphrase alone is enough to restore.

---

## 6. First run

```sh
sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos
sudo systemctl start borgbackup-job-nas.service
journalctl -u borgbackup-job-nas.service -f
```

Then export the repo key to Bitwarden as a second copy, in case the repo
header is ever damaged:

```sh
sudo borg key export ssh://borg@nas.lan:2222/backup/ryans-nixos/repo
```

Expect the first run to take a while and later runs to move very little.
Helium and Claude Code write while the job runs, so a few files land
mid-write. Nothing here is a database that cannot be reopened, so this is
acceptable; close Helium first if you want a clean profile snapshot.

---

## 7. Verify, then trust

Do this once now and once a quarter. A backup you have never restored is a
hypothesis.

```sh
set -x BORG_REPO ssh://borg@nas.lan:2222/backup/ryans-nixos/repo
set -x BORG_PASSCOMMAND "sudo cat /run/secrets/borg/passphrase"
set -x BORG_RSH "ssh -i /run/secrets/borg/ssh-key"

borg list
borg extract --dry-run --list ::(borg list --last 1 --format '{name}')

mkdir -p /tmp/restore-test; cd /tmp/restore-test
borg extract ::ARCHIVE home/ryan/resume
diff -r home/ryan/resume ~/resume
```

---

## 8. Retention and integrity, from the admin key

Append-only means the repository grows forever until an admin trims it. Do
this every few months, from the laptop, with the admin key pulled out of
Bitwarden into a tmpfs and deleted afterwards.

```sh
set -x BORG_RSH "ssh -i /tmp/borg-admin"
set -x BORG_REPO ssh://borg@nas.lan:2222/backup/ryans-nixos/repo

borg prune --list --keep-daily 7 --keep-weekly 4 --keep-monthly 12
borg compact
borg check --verify-data     # slow; reads everything
```

`borg check` can also run on the NAS itself against `/backup`, which avoids
pulling every chunk over the network. Either is fine, but it must happen.

---

## Recovering onto new hardware

1. Restore the age key to `/etc/nixos-secrets/age.key` from Bitwarden.
2. `nixos-rebuild switch` this flake, which lands the borg key and passphrase.
3. `borg extract` from the newest archive.

If the age key is gone, the passphrase in Bitwarden still opens the
repository directly. That is why both are stored, and why neither is inside
the backup.
