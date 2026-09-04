{
  config,
  pkgs,
  hyprland,
  fenix,
  ...
}: let
  start-hyprland = pkgs.writeShellApplication {
    name = "start-hyprland";
    text = ''
      exec uwsm start hyprland-uwsm.desktop >/dev/null 2>&1
    '';
  };
in {
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

    # Without this a fresh machine compiles Hyprland from source, because the
    # flake input tracks git rather than nixpkgs.
    extra-substituters = ["https://hyprland.cachix.org"];
    extra-trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

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

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal-hyprland = hyprland.packages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    })

    fenix.overlays.default

    # One derivation holding the whole Rust toolchain, every component taken
    # from the same upstream stable manifest. Single source of truth so the
    # editor's rust-analyzer can never drift from the compiler it analyses
    # against; bump it with `nix flake update fenix`.
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
      user = "ryan";
    };
  };

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    vim
    start-hyprland
  ];

  # Dedicated stack so the lock screen skips the failure delay
  security.pam.services.quickshell-password = {
    unixAuth = true;
    nodelay = true;
  };

  # Panther Lake Xe3 needs a current kernal; there is no i915 fallback
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [intel-media-driver vpl-gpu-rt];
  };
  
  services.thermald.enable = true;

  services.power-profiles-daemon.enable = true;

  # D-Bus power state for the shell and upower CLI.
  services.upower.enable = true;

  # Helium extensions are declared in home/packages.nix and loaded via
  # --load-extension from pinned web store CRXes. Enterprise policy
  # (force_installed) is not used: Helium's policy-driven CRX download is
  # broken upstream (imputnet/helium#1737), and a managed extension blocks
  # every other install path with a "blocked by the administrator" error.

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-color-emoji
    inter
  ];

  fonts.fontconfig = {
    # eDP-1 is a 1920x1200 OLED at 163 DPI. Subpixel rendering assumes a vertical
    # RGB stripe, and this panel's layout is not exposed anywhere we can read, so
    # the colour fringes it produces are a gamble that only paid off on the denser
    # 2880x1800 panel that preceded it, where they were too small to see.
    # Grayscale has no layout to get wrong.
    subpixel.rgba = "none";
    hinting = {
      enable = true;
      # Full hinting distorts outlines to put stems on whole pixels. That trade
      # is worth less at 163 DPI than the even spacing slight hinting keeps, and
      # slight is the better partner for grayscale.
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
