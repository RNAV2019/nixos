{
  config,
  lib,
  pkgs,
  fenix,
  user,
  ...
}: let
  start-hyprland = pkgs.writeShellApplication {
    name = "start-hyprland";
    text = ''
      exec uwsm start hyprland-uwsm.desktop >/dev/null 2>&1
    '';
  };
in {
  imports = [
    ./boot.nix
    ./users.nix
    ./secrets.nix
    ./wifi.nix
    ./backups.nix
  ];

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };
  console.keyMap = "uk";

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  # Ventoy ships unauditable binary blobs (NixOS/nixpkgs#404663). Pinned so a bump fails loudly.
  nixpkgs.config.permittedInsecurePackages = ["ventoy-1.1.17"];

  networking.networkmanager.enable = true;

  # LocalSend (discovery + transfer on port 53317)
  networking.firewall.allowedTCPPorts = [53317];
  networking.firewall.allowedUDPPorts = [53317];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };
  services.blueman.enable = true;

  # Required for Bluetooth HID input.
  services.libinput.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  # Stock nixpkgs package: Hydra-built (cache.nixos.org) and built against the
  # same glibc as the system mesa, so /run/opengl-driver always loads.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Modern Hyprland packages wrap bin/Hyprland in a shell script, which the
  # capability wrapper's ELF check rejects (NixOS/nixpkgs#573049). Point the
  # wrapper at the real binary inside the wrapper instead.
  security.wrappers.Hyprland.source =
    lib.mkForce "${config.programs.hyprland.package}/bin/.Hyprland-wrapped";

  nixpkgs.overlays = [
    fenix.overlays.default

    # Whole Rust toolchain from one stable manifest, so rust-analyzer never drifts
    # from rustc. Bump with `nix flake update fenix`.
    (final: _prev: {
      rustToolchain = final.fenix.combine (with final.fenix.stable; [
        cargo
        clippy
        rust-analyzer
        rust-src
        rustc
        rustfmt
      ]);
    })
  ];

  programs.uwsm.enable = true;

  # Quickshell locks the autologin session before desktop helpers start.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${start-hyprland}/bin/start-hyprland";
      inherit user;
    };
  };

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    vim
    start-hyprland
    # The Hyprland wrapper override above skips the script's PATH suffix, so the
    # dialog helpers Hyprland probes for (hyprland-dialog) must be on PATH here.
    hyprland-qtutils
    # Multiboot USB writer. Writes raw block devices, so not home.packages: sudo resets PATH.
    ventoy-full
  ];

  # Dedicated stack so the lock screen skips the failure delay
  security.pam.services.quickshell-password = {
    unixAuth = true;
    nodelay = true;
  };

  # Compressed swap in RAM, used ahead of the disk swap partition (higher priority).
  zramSwap.enable = true;

  services.power-profiles-daemon.enable = true;

  # D-Bus power state for the shell and upower CLI.
  services.upower.enable = true;

  # Helium extensions load from pinned CRXes in home/packages.nix rather than
  # enterprise policy, which is broken upstream (imputnet/helium#1737).
  # Other policies do work; Helium reads Chromium's path. This one hides the "unsupported
  # command-line flag" infobar for the launcher's --disable-blink-features (home/themes/helium.nix).
  environment.etc."chromium/policies/managed/helium.json".text = builtins.toJSON {
    CommandLineFlagSecurityWarningsEnabled = false;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-color-emoji
    inter
  ];

  fonts.fontconfig = {
    hinting = {
      enable = true;
      # Keeps glyph spacing even and suits grayscale better than full hinting.
      style = "slight";
    };
    defaultFonts = {
      sansSerif = ["Inter" "Noto Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
      emoji = ["Noto Color Emoji"];
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common = {
      default = ["hyprland" "gtk"];
      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      "org.freedesktop.impl.portal.Settings" = ["gtk"];
    };
  };

  # Wayland privilege prompts.
  security.polkit.enable = true;

  # GTK/libadwaita color-scheme support.
  programs.dconf.enable = true;

  # Nautilus trash, recent files, and mounts.
  services.gvfs.enable = true;
}
