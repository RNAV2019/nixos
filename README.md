# nixos

> A flake-based NixOS config — Hyprland on Wayland, Rose Pine everywhere.

<br>

![Desktop](screenshots/desktop.png)

<br>

## Stack

| Layer | Choice |
|---|---|
| OS | NixOS unstable, flakes |
| Compositor | Hyprland (UWSM session) |
| Display mgr | greetd, autologin |
| Lock / idle | quickshell + hypridle |
| Shell (bar, panels, notifs, OSD, lock) | quickshell · mycelium |
| Wallpaper | awww |
| Shell | fish + starship + atuin + zoxide + fzf |
| Terminal | ghostty |
| Editor | helix |
| Browser | helium |
| Bootloader | limine (Rose Pine themed) |
| Theme | Rose Pine Moon |

<br>

## Screenshots

<table>
  <tr>
    <td align="center"><img src="screenshots/terminal.png" alt="Terminal"/><br><sub>Terminal</sub></td>
    <td align="center"><img src="screenshots/browser.png" alt="Browser"/><br><sub>Browser</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/lockscreen.png" alt="Lockscreen"/><br><sub>Lockscreen</sub></td>
    <td align="center"><img src="screenshots/desktop.png" alt="Desktop"/><br><sub>Desktop</sub></td>
  </tr>
</table>

<br>

## Layout

```
.
├── flake.nix
├── host/
│   ├── configuration.nix          # networking, users, locale, limine
│   └── hardware-configuration.nix
├── modules/system/                # greetd, hyprland, fonts, …
└── home/
    ├── default.nix                # entry point, XDG, session vars
    ├── desktop.nix                # hyprland, quickshell, hypridle, fuzzel
    ├── shell.nix                  # fish, starship, atuin, zoxide, fzf, git
    ├── terminal.nix               # ghostty
    ├── editors.nix                # helix
    ├── programs.nix               # GUI/CLI apps
    ├── dev.nix                    # languages & toolchains
    ├── packages.nix               # flat user package list
    ├── custom-packages.nix
    ├── quickshell/                # QML shell: bar, panels, notifs, OSD, lock
    ├── themes/                    # Rose Pine Moon colour files
    └── backgrounds.nix            # wallpaper install + default symlink
```

<br>

## Installation

> Requires a working NixOS install with flakes enabled.

```bash
git clone https://github.com/RNAV2019/nixos ~/nixos

sudo nixos-generate-config --show-hardware-config > ~/nixos/host/hardware-configuration.nix

# Edit host/configuration.nix — hostname, username, timezone, locale
# Edit flake.nix — rename nixosConfigurations.<name>
# Edit home/default.nix — home.username / homeDirectory

sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos
```

<br>

## Daily Ops

```bash
rebuild           # sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos
nix flake update  # bump all inputs
nix-clean         # garbage-collect old generations
```

<br>

## AI Commit Messages

`gen-commit` generates a Conventional Commit message from the staged Git
snapshot and commits it only after explicit confirmation. Repository status
and diff content are sent to OpenRouter.

Set up the API key without placing it directly in shell history:

```bash
read -rsp "OpenRouter API key: " key; echo
gen-commit --key "$key"
unset key
```

Run it inside a Git working tree:

```bash
gen-commit
gen-commit --model google/gemini-2.5-flash-lite
```

The interaction follows these rules:

- Existing staged changes are the complete commit scope; unstaged and
  untracked changes are reported but excluded.
- With an empty index, choose either `Stage all and continue` or `Cancel`.
- `Edit with AI` requests a refinement and returns to the preview.
- `Edit manually` opens the configured Git editor and returns to the preview.
- The fullscreen TUI redraws after each action and after returning from the
  configured editor, without leaving duplicate previews in shell history.
- Only `Commit` creates a commit, and the full message is shown beforehand.
- Cancelling after `Stage all and continue` leaves those changes staged.
- The commit is blocked if the staged snapshot changes while the UI is open.
- Normal Git hooks still run and may reject or adjust the final commit.

Use `gen-commit --debug` to preserve temporary API diagnostics after the
command exits. Run its integration tests with:

```bash
nix build 'path:.#checks.x86_64-linux.gen-commit'
```

<br>

## Keybinds

| Key | Action |
|---|---|
| `Super + Return` | Terminal |
| `Super + Space` | App launcher (mycelium) |
| `Super + P` | Project picker |
| `Super + W` | Close window |
| `Super + L` | Lock |
| `Super + Escape` | Logout menu |
| `PrtSc` | Screenshot window |
| `Super + PrtSc` | Screenshot region |
| `Shift + PrtSc` | Screenshot monitor |

Full list in `home/desktop.nix`.
