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

  # Copilot key (Shift+Meta+F23) becomes Ctrl. PrtSc (Shift+Meta+S) and the Ideapad
  # screenshot button (which keyd rewrites to F16) become sysrq, Hyprland's Print.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        main."leftshift+leftmeta+f23" = "layer(control)";
        main."leftshift+leftmeta+s" = "sysrq";
        main.f16 = "sysrq";
      };
    };
  };

  # Mark keyd's virtual keyboard as internal so libinput's disable-while-typing
  # still pairs it with the touchpad.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd virtual keyboard]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

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
    # Multiboot USB writer. Writes raw block devices, so not home.packages: sudo resets PATH.
    ventoy-full
  ];

  # Dedicated stack so the lock screen skips the failure delay
  security.pam.services.quickshell-password = {
    unixAuth = true;
    nodelay = true;
  };

  # Panther Lake Xe3 needs a current kernel; there is no i915 fallback
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [intel-media-driver vpl-gpu-rt];
  };

  # Compressed swap in RAM; there is no swap partition.
  zramSwap.enable = true;

  services.thermald.enable = true;

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
    # The OLED's subpixel layout is unknown, so grayscale AA avoids colour fringes.
    subpixel.rgba = "none";
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
