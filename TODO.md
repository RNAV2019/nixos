# TODO

## 1. Declare a user password and add the Hyprland binary cache

Both are day-one blockers on fresh hardware.

- [x] Set `users.users.ryan.hashedPasswordFile` (or `initialPassword` as a stopgap).
      Greetd autologins, but sudo and the quickshell lock screen need a password.
- [x] Add the Hyprland Cachix substituter to `nix.settings`, otherwise a new
      machine compiles Hyprland from source.

## 2. Add secrets management

- [x] Adopt sops-nix (or agenix).
- [x] Move SSH keys, the gh token, cloudflared tunnel credentials, and API keys
      out of imperative home state and into it.
      Done for the gh token, cloudflared credentials, and the OpenRouter keys.
      SSH deferred: no private key exists on this machine yet.

## 3. Back up to the NAS with Borg

Declared in `modules/system/backups.nix` and `nas/`. Pika Backup is not used:
`backup mount` covers browsing and its config would not be declarative anyway.
The runbook below is written out in full in `BACKUPS.md`.

- [x] Run `borg serve` in a Docker container on the UGREEN DH4300 Plus, over SSH,
      with `--append-only` on the server side. Reached through a Cloudflare
      tunnel rather than a forwarded port, so it works away from home too.
- [x] Drive backups from `services.borgbackup.jobs`, passphrase from sops-nix.
- [x] Back up data, not config. Added Atuin and Zoxide on top of the original
      list, without which a restored machine has no shell history.
- [x] A `backup` command wrapping create, list, restore, mount and check.
- [ ] Create the tunnel and the Access service token (`BACKUPS.md` steps 1-2).
- [ ] Bring the containers up on the NAS and pin `nasHostKey` (steps 3-5).
- [ ] Generate the keypairs, load the four secrets, seed over the LAN (step 6).
- [ ] Store the passphrase, both private keys and the service token in
      Bitwarden, outside the backup.
- [ ] Perform a real test restore, and put `borg check` in the calendar
      quarterly.

## 4. Harden the boot to login flow and polish the lock screen

Full write-up, including verification steps and the seven still-unverified
assumptions, lives in
`~/.claude/plans/use-subagents-analyze-omarchy-rustling-peach.md`.

Greetd autologins, so `Lock.qml` is both the login screen and the only
credential gate on this machine. Do these in order; the escape hatches come
before anything that can lock you out.

- [ ] Extract `home/quickshell/Lock/LockView.qml` from `Lock.qml` at the
      `WlSessionLockSurface` boundary, parameterised by screen and state. Host it
      from a `quickshell-lock-preview` `PanelWindow` driven over IPC
      (`preview`, `previewPassword`, `previewStatus`, `previewBusy`, `status`).
      Do this first: every visual change below edits a screen that can lock you
      out, and the same extraction is most of a greetd migration if that ever
      happens.
- [ ] Set `misc.allow_session_lock_restore = true` in `home/desktop.nix`.
      `ext-session-lock` outlives its client, and without this a crashed
      Quickshell leaves the compositor's black failsafe up with no way back in.
      Recovery today is a TTY plus
      `hyprctl keyword misc:allow_session_lock_restore 1`.
- [ ] Add a `hyprland-session-locked` script reading `.solitaryBlockedBy` from
      `hyprctl -j monitors`. Exit 0 locked, 1 unlocked, 2 undetermined.
- [ ] Rewrite the `markerCheck` startup logic. The marker only proves this
      compositor instance was secured once, so a shell that crashed *while
      locked* matches it too and currently sets `sessionReady` behind an
      orphaned lock. Marker absent means lock without probing; marker present
      needs the probe to decide. Route the `lockdown` submap reset through
      exactly three paths so it can never survive and leave the keyboard dead.
- [ ] Guard on screen availability before locking: a `realScreenCount()` over
      `Quickshell.screens`, a stabilize timer, and a queued lock request.
      Separate lock *intent* from `lockContext.locked`/`.secure`, and move
      `passwordPam.start()` to where `locked` is actually set.
- [ ] Fix multi-monitor before the animation work, not after. Each output
      currently gets its own `TextInput` with `focus: true` and its own
      full-screen blur. Upstream reports this desyncs submit state and stalls
      unlock, so it is a correctness bug, not polish. Gate `canvas.visible` and
      `input.focus` on `Monitors.isFocused`.
- [ ] Supervise Quickshell with `systemd.user.services.quickshell` and
      `Restart = "always"`, matching the `awww-daemon` pattern. Qt exits via
      `_exit()` on Wayland connection loss, so `on-failure` never fires. Add a
      shell-level submap failsafe in `start-desktop`, since a QML watchdog
      cannot save you from QML failing to start.
- [ ] Add `no_anim` layer rules for the `quickshell-*` namespaces. Quickshell
      fades these itself and the compositor runs a second fade over the top.
- [ ] Lock screen polish, in this order:
      scope `content`'s `layer.enabled` to the cross-fade window only (it is
      permanently on, so every animated pixel forces a full-screen re-render,
      and this is what makes everything below it affordable);
      delete the widening field and its `TextMetrics` in favour of a fixed pill
      with a static error line beneath it;
      drop the leftover fingerprint glyph from the placeholder;
      add a `Translate`-based shake on failure and breathing dots while PAM is
      checking;
      caps-lock indicator from `/sys/class/leds/*capslock*`, but verify the LED
      is not inert on this laptop first;
      wallpaper `cache: true` with a `?v=N` query instead of a synchronous
      full-res decode on the first frame;
      move the lock's magic numbers into `Theme.qml` and add `animReveal`.
      Deliberately no battery, network, or notification chrome.
- [ ] Add `pam_faillock` to `quickshell-password`, `deny = 10` with
      `unlock_time = 120`. **Test `Ctrl+Alt+F2` while locked first** and do not
      ship this if a TTY is unreachable. Two NixOS traps: force `pam_unix`'s
      control to `[success=1 default=bad]` so `authsucc` is reached at all, and
      make `authsucc` `sufficient` so the module's trailing `pam_deny` does not
      undo it. `security.pam.services.<name>.rules` is experimental; re-read
      `nixos/modules/security/pam.nix` on channel bumps.
- [ ] Harden the suspend path. `hypridle` locks before sleep, which is exactly
      how an orphaned lock gets manufactured. Release the lock gracefully before
      suspend rather than relying on session lock restore alone.
- [ ] Replace the `bgrt` Plymouth theme with a Rose Pine script theme: `#191724`
      ground matching `Theme.base` and Hyprland's `background_color`, the nix
      snowflake recoloured to `#eb6f92` to match the bar, and three dots at the
      lock screen's password row position. No progress bar; there is no LUKS and
      nothing to stall on.
- [ ] Add `home/palette.nix` as the single source for the Nix-side consumers
      (Limine, fuzzel, Hyprland borders, Plymouth). Keep `Theme.qml` literal so
      hot reload survives, and add a `nix flake check` that fails on drift
      between the two.

## Later

- [ ] Swap or zram. Neither is configured, so there is no hibernate.
- [ ] Finish the KVM setup. The `kvm` group and `kvm-intel` are declared but no
      `virtualisation.libvirtd` or emulator config exists.
