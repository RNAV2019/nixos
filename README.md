<div align="center">

# nixos

**A flake-based NixOS desktop: Hyprland, a hand-built Quickshell shell, and runtime-switchable themes.**

[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-0.56-3eddb8)](https://hypr.land)
[![Quickshell](https://img.shields.io/badge/shell-Quickshell-3eddb8)](https://quickshell.org)
[![Theme: Ariadne](https://img.shields.io/badge/theme-Ariadne-002018)](#themes)

<img src="showcase.webp" alt="A walkthrough of the desktop: the island, launcher, terminal, editor, browser, control centre, calendar, Nearby, wallpaper and theme pickers, and the lock screen" width="100%">

</div>

## Highlights

- **A morphing island shell.** One pill at the top of the screen grows into every surface: launcher, control centre, calendar, wallpaper and theme pickers, Nearby sharing, power profiles, the screen recorder, notifications, OSDs, the session menu and polkit prompts. Written in QML under [`home/quickshell`](home/quickshell).
- **Live theme switching.** `Alt + T` recolours the shell, Hyprland, Ghostty, fish, Helix, GTK and Helium in place, with no rebuild. Ships **Ariadne** (the default), **Rosé Pine** and **ASCII World**.
- **Quick Share and AirDrop** from the Nearby panel (`Alt + N`). Files dragged anywhere in the compositor travel as a card pile drawn by [`dragpile`](pkgs/dragpile), a small Hyprland plugin.
- **A locked-down session.** greetd autologin goes straight to a Quickshell lock screen that is secured before any desktop helper starts. Secrets are kept in sops-nix, and borg backs up to a NAS every day.
- **Its own tooling.** Custom tools are packaged as a flake overlay in [`pkgs/`](pkgs), with tests next to them.

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="screenshots/island.png" alt="Expanded island"><br><sub><b>Island</b>, showing what's playing, the week ahead and system gauges</sub></td>
    <td width="50%"><img src="screenshots/control.png" alt="Control centre"><br><sub><b>Control centre</b> (<code>Alt + A</code>)</sub></td>
  </tr>
  <tr>
    <td><img src="screenshots/launcher.png" alt="Launcher"><br><sub><b>Launcher</b> (<code>Super + Space</code>)</sub></td>
    <td><img src="screenshots/calendar.png" alt="Calendar"><br><sub><b>Calendar</b>, from Google Calendar via iCal (<code>Alt + C</code>)</sub></td>
  </tr>
  <tr>
    <td><img src="screenshots/theme.png" alt="Theme picker"><br><sub><b>Theme picker</b> (<code>Alt + T</code>)</sub></td>
    <td><img src="screenshots/wallpaper.png" alt="Wallpaper picker"><br><sub><b>Wallpaper picker</b> (<code>Ctrl + Super + Space</code>)</sub></td>
  </tr>
  <tr>
    <td><img src="screenshots/nearby.png" alt="Nearby"><br><sub><b>Nearby</b>: Quick Share and AirDrop (<code>Alt + N</code>)</sub></td>
    <td><img src="screenshots/notification.png" alt="Notification"><br><sub><b>Notifications</b> grow out of the island</sub></td>
  </tr>
  <tr>
    <td><img src="screenshots/terminal.png" alt="Ghostty and Helix"><br><sub><b>Ghostty</b> running fastfetch next to <b>Helix</b></sub></td>
    <td><img src="screenshots/browser.png" alt="Helium"><br><sub><b>Helium</b>, themed to match</sub></td>
  </tr>
  <tr>
    <td><img src="screenshots/lockscreen.png" alt="Lock screen"><br><sub><b>Lock screen</b> (<code>Super + L</code>)</sub></td>
    <td><img src="screenshots/session.png" alt="Session menu"><br><sub><b>Session menu</b> (<code>Super + Escape</code>)</sub></td>
  </tr>
</table>

## Stack

| | |
|---|---|
| **OS** | NixOS unstable, flakes, home-manager |
| **Session** | Hyprland (Lua config) on UWSM, greetd autologin, limine and plymouth |
| **Shell UI** | Quickshell: bar, island, every panel, notifications, OSD, lock screen and polkit agent |
| **Wallpaper** | awww |
| **Terminal** | Ghostty, herdr, fish, starship, atuin, zoxide, fzf |
| **Editor** | Helix (Steel plugin fork) |
| **Browser** | Helium, with extensions pinned in Nix and a theme extension per palette |
| **AI** | Claude Code, opencode, T3 Code nightly |
| **Tools** | `gen-commit`, `ical-agenda`, `note-tui`, `backup`, `showcase`, … |
| **Secrets / backups** | sops-nix (age); borg to a NAS over a Cloudflare tunnel |

## Themes

`theme-switch <ariadne|rose-pine|dark>`, or `Alt + T`, swaps one symlink to a generated
theme directory and nudges each running program to pick it up. Palettes are defined in
[`home/themes/palettes.nix`](home/themes/palettes.nix), and every per-program fragment is
generated from them in [`home/theme.nix`](home/theme.nix). New installs start on Ariadne,
and each theme remembers its own last wallpaper.

## Layout

```
.
├── flake.nix             # hosts via mkHost; exports the pkgs/ overlay, packages and checks
├── hosts/<hostname>/     # hardware, stateVersions, monitors
├── modules/system/       # boot, users, secrets, Wi-Fi, backups, shared system config
├── home/                 # home-manager: desktop, shell, terminal, editors, theme, apps
│   ├── quickshell/       # the QML shell, symlinked live from ~/nixos
│   └── themes/           # palettes and per-program theme sources
├── pkgs/                 # own tools as an overlay (pkgs.gen-commit, pkgs.showcase, …)
├── backgrounds/<theme>/  # wallpapers, grouped by theme
├── secrets/              # age-encrypted
└── screenshots/          # generated by `nix run .#showcase`
```

## Installation

> Needs a fresh NixOS install on an Intel machine with a user named `ryan`. Tick disk
> encryption in the installer; the hardware scan below records it.

```bash
# The repo must live at ~/nixos, because quickshell is symlinked from there.
nix-shell -p git --run 'git clone https://github.com/RNAV2019/nixos ~/nixos'
cd ~/nixos

# A new machine gets its own hosts/<name>, which also becomes its hostname.
host=new-laptop
mkdir -p hosts/$host
sudo nixos-generate-config --show-hardware-config > hosts/$host/hardware-configuration.nix
```

For a new machine, write `hosts/$host/default.nix` based on `hosts/ryans-nixos`, keeping
only what is true of the new hardware: the hardware import, both `stateVersion`s, and
optionally `desktop.monitors`. Then add `$host = mkHost "$host";` to `flake.nix` and
`git add hosts/$host`, since flakes only see tracked files.

```bash
# The age key, restored from Bitwarden, is the only thing not in this repo.
sudo install -Dm600 /path/to/age.key /etc/nixos-secrets/age.key

# The first build has to enable flakes itself.
sudo NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild switch --flake ~/nixos#$host

# Restore data last, because it needs the secrets the rebuild just decrypted. Then reboot.
backup restore
```

None of the steps above bring back Bluetooth pairings or T3 Code and opencode history.

## Daily use

```bash
rebuild              # nixos-rebuild switch for this hostname
nix flake update     # bump inputs
nix flake check      # tool tests and qmlformat
nix-clean            # collect old generations
nix run .#showcase   # regenerate screenshots/ and showcase.webp
```

<details>
<summary><b>Secrets</b></summary>

`secrets/secrets.yaml` is encrypted with [sops-nix](https://github.com/Mic92/sops-nix). It
holds the login password hash, API tokens, the Cloudflare tunnel and Access credentials,
the borg passphrase and SSH key, and the calendar feed addresses. Wi-Fi passwords live in
`secrets/wifi.yaml`, and each network also needs an entry in `modules/system/wifi.nix`.

```bash
sudo edit-secrets             # secrets.yaml in Helix; re-encrypts on save
sudo edit-secrets wifi.yaml   # any other file under secrets/
```

To change the login password:

```bash
sudo -v && umask 077
mkpasswd -m yescrypt | jq -Rs 'rtrimstr("\n")' > /tmp/hash.json
sudo SOPS_AGE_KEY_FILE=/etc/nixos-secrets/age.key \
  sops set --value-stdin secrets/secrets.yaml '["users"]["ryan-hashed-password"]' < /tmp/hash.json
shred -u /tmp/hash.json && sudo chown ryan:users secrets/secrets.yaml
```

</details>

<details>
<summary><b>Face unlock</b></summary>

The lock screen can also open with [Howdy](https://github.com/boltgolt/howdy) and the laptop's
IR camera. It is an extra way in, never a replacement: the password field stays live and
focused, and works exactly as before whatever the camera does. The face runs as a second PAM
conversation on its own service, `quickshell-face`. Howdy is on no other service: `login`,
`sudo`, polkit and `quickshell-password` don't know about it
([`modules/system/face-unlock.nix`](modules/system/face-unlock.nix)).

Until a face is enrolled nothing happens: no scan, no ring, no error. To enrol, after a rebuild:

```bash
sudo linux-enable-ir-emitter configure   # once; follow the prompts until the IR light flickers
sudo howdy add                           # look at the IR camera; repeat in other light for better odds
sudo howdy test                          # optional: shows what the camera sees
```

`linux-enable-ir-emitter` is installed but its boot/resume service is not enabled. If the
emitter turns off after suspend, set `services.linux-enable-ir-emitter.enable = true` (device
`video2`) once it is configured.

The lock scans when it appears and again on wake from suspend. **Esc** on an empty field
scans again, up to three misses per lock (a wake starts the count afresh). A face match
unlocks exactly as the password does; typing the first character stops the scan. The IR
camera's path, the certainty (3.0, lower is stricter) and the 5 second timeout are in
`face-unlock.nix`.

To turn it off, either delete the model (`sudo howdy clear`), or remove
`./face-unlock.nix` from the imports in `modules/system/default.nix` and rebuild. Without the
`quickshell-face` service the shell skips the scan silently.

</details>

<details>
<summary><b>Polkit prompts</b></summary>

The shell is the session's polkit agent (`PolkitAgent` in
[`Services/Polkit.qml`](home/quickshell/Services/Polkit.qml), `security.polkit.enable` in
`modules/system/default.nix` only runs `polkitd`). Anything that asks for admin rights through
polkit (`pkexec`, Nautilus' admin actions, fwupd, NetworkManager) grows an
[authentication prompt](home/quickshell/Auth/AuthPrompt.qml) out of the island: who is asking,
polkit's message, the action id (open it for the program and the account that will approve), your
picture and name, and a password field. **Enter** authenticates, **Esc** cancels, **Tab** walks
the plate, the buttons and, with several administrators, an account chooser. A wrong password
shakes the pill and keeps "Sorry, that didn't work" up until the next keystroke. The prompt
holds the keyboard exclusively, goes away on approval, Cancel, polkitd withdrawing the request or
the session locking, and steps aside (then returns) when another panel takes the island.

The Quickshell the flake pins hands over the action id, message and accounts but not polkit's
`details` map, so the program is read back out of the message and the caller isn't shown.

Rehearse every state without a real request: `qs ipc call authpreview ask pkexec` (also `plain`,
`code`, `info`, `identities`, `long`), then `checking`, `fail ""`, `hide`. Polkit allows one agent
per session, so don't start a second shell to test it: `nix build .#checks.x86_64-linux.polkit-agent -L`
runs the real agent against a real `polkitd` and PAM in a VM of its own.

</details>

<details>
<summary><b>Backups</b></summary>

Borg pushes an archive every day to an append-only server on the NAS, through a Cloudflare
tunnel. If the NAS can't be reached, the run is skipped and the persistent timer catches
up later. The backup covers projects, documents, media folders, `~/.claude`, the Helium
profile, and the atuin and zoxide databases. It leaves out build outputs, virtualenvs and
anything tagged with `CACHEDIR.TAG`.

The job never creates the repository: run `borg init -e repokey-blake2` once by hand, using
`lanSeed` in `modules/system/backups.nix` for the first upload. This client's key can't
prune, so prune on the NAS with the admin key. `backup status` warns once there are 60
archives.

```bash
backup now | status | list [ARCHIVE] | restore [PATH...] | mount [ARCHIVE] | check [--data]
```

</details>

<details>
<summary><b>Showcase</b></summary>

`nix run .#showcase [--shots-only | --webp-only]` regenerates every image in this README, and
gives the same result on every run. It runs inside a nested Hyprland on a hidden workspace,
in a bubblewrap sandbox. That sandbox has a scratch `$HOME`, its own D-Bus and its own
runtime directory, so nothing personal is ever on screen. A made-up calendar, demo Nearby
devices, a silent "now playing" track and a frozen clock fill in for real data. The tour is
scripted in [`pkgs/showcase/showcase.sh`](pkgs/showcase/showcase.sh). The walkthrough is
recorded losslessly and encoded as a full-colour 1920×1200, 30 fps animated WebP, so unlike
a GIF it has no palette banding.

</details>

## Keybinds

| Key | Action | Key | Action |
|---|---|---|---|
| `Super + Return` | Terminal | `Alt + A` | Control centre |
| `Super + Shift + B` | Browser | `Alt + C` | Calendar |
| `Super + Shift + F` | Files | `Alt + N` | Nearby |
| `Super + Space` | Launcher | `Alt + T` | Theme picker |
| `Super + W` | Close window | `Ctrl + Super + Space` | Wallpaper picker |
| `Super + L` | Lock | `Alt + R` | Screen recorder |
| `Super + Escape` | Session menu | `Alt + P` | Power profiles |
| `PrtSc` | Screenshot region | `Super + PrtSc` | Colour picker |

The full list is in [`home/desktop.nix`](home/desktop.nix).
