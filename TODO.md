# TODO

## 1. Declare a user password and add the Hyprland binary cache

Both are day-one blockers on fresh hardware.

- [ ] Set `users.users.ryan.hashedPasswordFile` (or `initialPassword` as a stopgap).
      Greetd autologins, but sudo and the quickshell lock screen need a password.
- [ ] Add the Hyprland Cachix substituter to `nix.settings`, otherwise a new
      machine compiles Hyprland from source.

## 2. Add secrets management

- [ ] Adopt sops-nix (or agenix).
- [ ] Move SSH keys, the gh token, cloudflared tunnel credentials, and API keys
      out of imperative home state and into it.

## 3. Back up to the NAS with Borg

- [ ] Run `borg serve` in a Docker container on the UGREEN DH4300 Plus, over SSH,
      with `--append-only` on the server side.
- [ ] Drive backups from `services.borgbackup.jobs`, passphrase from sops-nix.
      Pika Backup is for browsing and restoring only; its config lives in dconf
      and is not declarative.
- [ ] Back up data, not config: `~/Projects`, `~/Work`, `~/Documents`, `~/resume`,
      `~/Pictures`, `~/.claude`, browser profiles.
      Exclude `~/.cache`, Trash, `~/.local/share/aube`, `target/`, `node_modules/`,
      and browser cache directories.
- [ ] Schedule `borg check` and perform a real test restore.
- [ ] Store the repo passphrase and SSH key in Bitwarden, outside the backup.

## Later

- [ ] Swap or zram. Neither is configured, so there is no hibernate.
- [ ] Finish the KVM setup. The `kvm` group and `kvm-intel` are declared but no
      `virtualisation.libvirtd` or emulator config exists.
