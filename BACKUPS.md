# Backups

The laptop pushes Borg archives to a container on the UGREEN DH4300 Plus. The
server is append-only, so nothing running on the laptop can destroy history.
It is reachable only through a Cloudflare tunnel, so no port is forwarded and
backups work identically at home and abroad.

Everything the laptop needs lives in `secrets/secrets.yaml`, which means a
rebuilt machine is four steps from being itself again.

| Piece | Where it is declared |
|---|---|
| Job, schedule, paths, excludes | `modules/system/backups.nix` |
| `backup` command | `modules/system/backup.sh` |
| Passphrase, SSH key, Access token | `modules/system/secrets.nix` |
| Server and tunnel | `nas/` |

<br>

## Daily use

```
backup now                    run a backup, spinner then a summary
backup now -v                 the same, streaming borg's log instead
backup status                 last run, next run, size, staleness
backup list                   every archive, newest first
backup list ARCHIVE           the files inside one
backup restore                pick an archive, restore all of it
backup restore ~/Work         pick an archive, restore just that path
backup restore --archive NAME skip the picker, for scripts
backup mount                  browse every archive, then: backup umount
backup mount ARCHIVE          browse just one
backup check                  verify integrity, --data reads every chunk
```

There is no `backup prune`. The server rejects deletion from this key, and
retention is done deliberately with the admin key; see below.

Backups also run on their own once a day. When the NAS is unreachable the unit
is skipped rather than failed, and the timer catches up at the next
opportunity, so an unreachable NAS never shows up as a red unit.

<br>

## What is backed up

`~/Projects`, `~/Work`, `~/Documents`, `~/resume`, `~/Pictures`, `~/Desktop`,
`~/Downloads`, `~/Music`, `~/Videos`, `~/.claude`, the Helium profile, and the
Atuin and Zoxide databases.

Roughly 4.5 GB after exclusions, of which build output is the largest thing
dropped. Cargo tags its own build directories and `--exclude-caches` removes
them automatically; `node_modules`, `.direnv` and `.venv` are named explicitly
because they do not tag themselves.

Two deliberate choices inside `~/.claude`. The settings file is excluded
because `home/claude.nix` rewrites it on every rebuild, so restoring it would
only create a conflict. The credentials file is kept, because it is what makes
Claude Code come back logged in.

<br>

## Setup

Steps marked **NAS** run on the UGREEN. Everything else runs on the laptop.
The order matters: the configuration will not build until the secrets exist.

### 1. Create the tunnel

The account is already authenticated, since `~/.cloudflared/cert.pem` comes
from sops.

```bash
cloudflared tunnel create borg-nas
cloudflared tunnel route dns borg-nas backup.ryannavsaria.co.uk
```

The first command prints a UUID and writes `~/.cloudflared/<UUID>.json`. Both
are needed on the NAS in step 3.

### 2. Create the Access application

In the Cloudflare Zero Trust dashboard:

1. **Access → Service Auth → Service Tokens → Create**. Name it `borg-nas`.
   Copy the Client ID and Client Secret now; the secret is shown once.
2. **Access → Applications → Add an application → Self-hosted**. Set the
   domain to `backup.ryannavsaria.co.uk`.
3. Give it one policy: action **Service Auth**, include **Service Token** →
   `borg-nas`.

Without a policy the hostname is open to anyone who knows it, leaving the SSH
key as the only barrier. With one, an attacker needs a Cloudflare credential
before the SSH handshake even begins.

### 3. **NAS** Put the server up

Copy the `nas/` directory from this repo to wherever Docker apps live on the
UGREEN, then:

```bash
cd /volume1/docker/borg          # adjust to your own path
mkdir -p backup sshkeys/clients
chown -R 1000:1000 backup sshkeys

# The tunnel credentials from step 1. The UUID is already in config.yml.
cp ~/.cloudflared/b2e69025-7f91-4e01-a951-c997811473af.json \
   cloudflared/credentials.json

# The cloudflared image drops privileges, so root-owned or mode 600 files are
# unreadable to it and the container exits with "permission denied" on
# config.yml. Find the uid with:
#   docker run --rm --entrypoint id cloudflare/cloudflared:latest
chown -R <uid>:<uid> cloudflared
chmod 700 cloudflared
chmod 600 cloudflared/config.yml cloudflared/credentials.json
```

Uncomment the `ports:` block in `docker-compose.yml`, which exists only for
the seed in step 6, then wait for step 5 before starting anything: the daemon
refuses to come up until at least one client key is present.

### 4. Generate the keys

```bash
cd "$(mktemp -d)"
ssh-keygen -t ed25519 -N "" -C "borg ryans-nixos" -f ryans-nixos
ssh-keygen -t ed25519 -N "" -C "borg admin"       -f borg-admin
openssl rand -base64 32
```

Put five things in Bitwarden before going further: the passphrase from
`openssl`, both private keys, the Access service token from step 2, and a note
pointing at this file. None of it can be recovered from the backup.

### 5. **NAS** Install the client keys and start

Copy `ryans-nixos.pub` and `borg-admin.pub` across. The filename becomes the
repository directory, so drop the extension:

```bash
cp ryans-nixos.pub sshkeys/clients/ryans-nixos
cp borg-admin.pub  sshkeys/clients/borg-admin
chown -R 1000:1000 sshkeys

docker compose up -d
docker exec borgserver borg --version                            # expect 1.4.x
docker exec borgserver cat /sshkeys/host/ssh_host_ed25519_key.pub
```

Paste the key material from that last line into `nasHostKey` in
`modules/system/backups.nix`, without the trailing `root@<container id>`
comment, which changes every time the container is recreated. While
`nasHostKey` is empty the laptop accepts whatever host key it is offered on
first contact.

### 6. Load the secrets and seed

```bash
sudo SOPS_AGE_KEY_FILE=/etc/nixos-secrets/age.key sops secrets/secrets.yaml
```

Add four values, with the private key as a literal block so its newlines
survive:

```yaml
borg:
    passphrase: <the openssl output>
    ssh-key: |
        -----BEGIN OPENSSH PRIVATE KEY-----
        ...
        -----END OPENSSH PRIVATE KEY-----
cloudflare:
    access-token-id: <client id>
    access-token-secret: <client secret>
```

```bash
sudo chown ryan:users secrets/secrets.yaml
```

Now set `lanSeed` in `modules/system/backups.nix` to the NAS's address on your
own network, as `host:port`, for example `192.168.1.20:2222`. That drops the
tunnel for one run. Sending the first archive through Cloudflare pushes it up
your home link and pulls it straight back down again; on the LAN it is a few
minutes.

```bash
rebuild
backup now
```

Then set `lanSeed` back to `null`, `rebuild`, and comment the `ports:` block
back out on the NAS.

Borg records where it last saw a repository and refuses to continue when the
address changes, which is exactly what switching off the seed does. The prompt
cannot be answered by a systemd job, so acknowledge the move once for each
user that talks to the repository. Borg then stores the new location and never
asks again:

```bash
env BORG_RELOCATED_REPO_ACCESS_IS_OK=yes borg-job-nas list >/dev/null
sudo BORG_RELOCATED_REPO_ACCESS_IS_OK=yes borg-job-nas list >/dev/null
```

Borg identifies a repository
by its id rather than its address, so the switch changes nothing and the local
chunk cache stays warm.

### 7. Verify

```bash
backup status
backup list
sudo borg key export ssh://borg@backup.ryannavsaria.co.uk/backup/ryans-nixos/repo
```

Put that exported key in Bitwarden too. It is a second way in if the
repository header is ever damaged.

Then do a real restore, because a backup you have never restored is a
hypothesis:

```bash
backup mount
diff -r "$XDG_RUNTIME_DIR"/backup/home/ryan/resume ~/resume
backup umount
```

<br>

## New hardware

```bash
git clone https://github.com/RNAV2019/nixos ~/nixos
sudo nixos-generate-config --show-hardware-config > ~/nixos/host/hardware-configuration.nix
sudo install -Dm600 /path/to/age.key /etc/nixos-secrets/age.key
sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos

backup restore
```

The rebuild has to come third. It is what turns the encrypted file into the
borg key, the passphrase and the Access token that the restore then needs.

Restore from a fresh session with Helium closed; the command refuses to run
otherwise, because overwriting a live browser profile corrupts it. Log out and
back in afterwards.

The first backup after a restore re-downloads the chunk index, so it is slow
once and normal thereafter.

<br>

## Retention and integrity

Append-only means the repository grows until an admin trims it. Every few
months, with the admin key pulled out of Bitwarden:

```bash
install -m600 /path/to/borg-admin /tmp/borg-admin

# cloudflared reads these from the environment; the tunnel is behind Access
# for the admin key exactly as it is for the laptop key.
export TUNNEL_SERVICE_TOKEN_ID="$(cat /run/secrets/cloudflare/access-token-id)"
export TUNNEL_SERVICE_TOKEN_SECRET="$(cat /run/secrets/cloudflare/access-token-secret)"

export BORG_RSH="ssh -i /tmp/borg-admin -o ProxyCommand='cloudflared access ssh --hostname backup.ryannavsaria.co.uk'"
export BORG_REPO=ssh://borg@backup.ryannavsaria.co.uk/backup/ryans-nixos/repo
export BORG_PASSCOMMAND="cat /run/secrets/borg/passphrase"

borg prune --list --keep-daily 7 --keep-weekly 4 --keep-monthly 12
borg compact
shred -u /tmp/borg-admin
```

`backup check` runs read-only and needs no admin key. Run it quarterly, and
`backup check --data` yearly.

<br>

## Things that will bite you

**Browser sessions are portable only because there is no keyring.** This
machine runs neither gnome-keyring nor kwallet, so Chromium falls back to its
basic password store, whose key is a build-time constant. Every cookie in the
profile carries the `v10` prefix that marks it. Enabling a keyring later would
switch new cookies to `v11` and bind them to that machine, and a restored
profile would come back logged out of everything. Nothing warns you.

**Bitwarden is the single point of failure.** The age key opens sops, sops
holds everything else. Lose Bitwarden and the laptop together and the archives
are unreadable. The passphrase stored alongside is the hedge: it opens the
repository directly, with no age key involved.

**An interrupted backup leaves data on the server.** Borg rolls the
transaction back on the client, but an append-only server keeps what was
already written. This is expected; `borg compact` under the admin key reclaims
it.

**The client version must track the server.** The laptop runs borg 1.4.x from
nixpkgs and the container is pinned to the Debian release that matches. A
nixpkgs bump to borg 2 would need the image tag moved and the repository
migrated, in that order.
