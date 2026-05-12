# nixos

My personal NixOS configuration — a flake-based Hyprland desktop with home-manager, themed in Rose Pine.

## Stack

| Layer        | Choice                                              |
| ------------ | --------------------------------------------------- |
| OS           | NixOS unstable, flakes                              |
| Compositor   | Hyprland (UWSM session)                             |
| Display mgr  | greetd, autologin straight into Hyprland            |
| Lock / idle  | hyprlock + hypridle                                 |
| Bar / launcher / notifs | waybar · fuzzel · mako                   |
| Wallpaper    | awww                                                |
| Shell        | fish + starship + atuin + zoxide + fzf              |
| Terminal     | ghostty                                             |
| Editor       | helix                                               |
| Browser      | helium                                              |
| Theme        | Rose Pine (everywhere)                              |

## Layout

```
.
├── flake.nix              # Inputs, host definition (ryans-nixos)
├── host/
│   ├── configuration.nix  # Core system: networking, users, locale
│   └── hardware-configuration.nix
├── modules/system/        # System-level modules (greetd, hyprland, fonts, …)
└── home/                  # home-manager — split by concern
    ├── default.nix        # Entry point, XDG, session vars
    ├── desktop.nix        # Hyprland, waybar, mako, hyprlock, hypridle
    ├── shell.nix          # fish, starship, atuin, zoxide, fzf, git, delta
    ├── terminal.nix       # ghostty
    ├── editors.nix        # helix
    ├── programs.nix       # GUI/CLI apps (lazygit, btop, zathura, …)
    ├── dev.nix            # Languages & toolchains
    ├── packages.nix       # Flat user package list
    ├── custom-packages.nix
    └── backgrounds.nix    # Wallpaper installation + default link
```

## Installation

> Assumes a working NixOS install with flakes enabled.

```bash
# 1. Clone
git clone https://github.com/RNAV2019/nixos ~/nixos
cd ~/nixos

# 2. Generate your hardware config
sudo nixos-generate-config --show-hardware-config > host/hardware-configuration.nix

# 3. Adjust host/configuration.nix
#    - hostname (currently `ryans-nixos`)
#    - username (currently `ryan`)
#    - timezone, locale, keymap
#
#    Also rename the host in flake.nix → nixosConfigurations.<name>
#    and in home/default.nix → home.username / homeDirectory.

# 4. Build & switch
sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos
```

The `rebuild` fish alias wraps step 4 for day-to-day use.

## Daily ops

```bash
rebuild           # sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos
nix flake update  # bump all inputs
nix-clean         # garbage-collect old generations
```

If a rebuild leaves you without a working session, pick an older generation in GRUB, or drop to a TTY with **Ctrl+Alt+F2**.

## Keybinds (cheatsheet)

| Key                | Action                |
| ------------------ | --------------------- |
| `Super + Return`   | Terminal              |
| `Super + Space`    | App launcher (fuzzel) |
| `Super + W`        | Close window          |
| `Super + L`        | Lock                  |
| `Super + Escape`   | Logout menu           |
| `PrtSc`            | Screenshot window     |
| `Super + PrtSc`    | Screenshot region     |
| `Shift + PrtSc`    | Screenshot monitor    |

See `home/desktop.nix` for the full set.
