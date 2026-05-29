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
| Lock / idle | hyprlock + hypridle |
| Bar / launcher / notifs | waybar · fuzzel · mako |
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
    ├── desktop.nix                # hyprland, waybar, mako, hyprlock, hypridle
    ├── shell.nix                  # fish, starship, atuin, zoxide, fzf, git
    ├── terminal.nix               # ghostty
    ├── editors.nix                # helix
    ├── programs.nix               # GUI/CLI apps
    ├── dev.nix                    # languages & toolchains
    ├── packages.nix               # flat user package list
    ├── custom-packages.nix
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

## Keybinds

| Key | Action |
|---|---|
| `Super + Return` | Terminal |
| `Super + Space` | App launcher (fuzzel) |
| `Super + W` | Close window |
| `Super + L` | Lock |
| `Super + Escape` | Logout menu |
| `PrtSc` | Screenshot window |
| `Super + PrtSc` | Screenshot region |
| `Shift + PrtSc` | Screenshot monitor |

Full list in `home/desktop.nix`.
