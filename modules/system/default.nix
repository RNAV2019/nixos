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

  services.fprintd.enable = true;

  # Fingerprint auth for login and privileged prompts.
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.login.fprintAuth = true;
  security.pam.services.greetd.fprintAuth = true;
  security.pam.services.polkit-1.fprintAuth = true;

  # Separate stacks keep pam_fprintd from blocking password entry.
  security.pam.services.quickshell-password = {
    unixAuth = true;
    fprintAuth = false;
    nodelay = true;
  };
  security.pam.services.quickshell-fingerprint = {
    unixAuth = false;
    fprintAuth = true;
  };

  services.power-profiles-daemon.enable = true;

  # D-Bus power state for the shell and upower CLI.
  services.upower.enable = true;

  # Force-install Helium extensions through Chromium policy.
  environment.etc."chromium/policies/managed/helium-extensions.json".text = builtins.toJSON {
    ExtensionInstallForcelist = [
      "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx"
      "oemmndcbldboiebfnladdacbdfmadadm;https://clients2.google.com/service/update2/crx"
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-color-emoji
    inter
  ];

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
