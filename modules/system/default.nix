{
  config,
  pkgs,
  hyprland,
  ...
}: let
  start-hyprland = pkgs.writeShellApplication {
    name = "start-hyprland";
    text = ''
      exec uwsm start hyprland-uwsm.desktop
    '';
  };
in {
  # Locale, timezone and keymaps
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

  # Nix settings
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
  };

  # Garbage collector for older generations
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Networking
  networking.networkmanager.enable = true;

  # LocalSend (discovery + transfer on port 53317)
  networking.firewall.allowedTCPPorts = [53317];
  networking.firewall.allowedUDPPorts = [53317];

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };
  services.blueman.enable = true;

  # Bluetooth HID devices (e.g. MX Master 2S) to produce input events.
  services.libinput.enable = true;

  # Sound
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  # Hyprland at system level
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Override nixpkgs xdg-desktop-portal-hyprland with the flake version
  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal-hyprland = hyprland.packages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    })
  ];

  # UWSM (hyprland-uwsm.desktop is provided by programs.hyprland.withUWSM)
  programs.uwsm.enable = true;

  # Quickshell locks the autologin session before desktop helpers start.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${start-hyprland}/bin/start-hyprland";
      user = "ryan";
    };
  };

  # Fish shell
  programs.fish.enable = true;

  # Essential system packages
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    vim
    start-hyprland
  ];

  # Fingerprint reader
  services.fprintd.enable = true;

  # PAM fingerprint auth for sudo, login, lock screen, and GUI privilege prompts
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

  # Power profiles daemon
  services.power-profiles-daemon.enable = true;

  # UPower — battery/AC state via D-Bus. Required for `upower` CLI and
  # the battery panel in the shell to query device state.
  services.upower.enable = true;

  # Helium browser extensions via Chromium managed policy
  environment.etc."chromium/policies/managed/helium-extensions.json".text = builtins.toJSON {
    ExtensionInstallForcelist = [
      "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx"
      "oemmndcbldboiebfnladdacbdfmadadm;https://clients2.google.com/service/update2/crx"
    ];
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-color-emoji
    inter
  ];

  # XDG portal for file pickers, screen sharing etc
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common = {
      default = ["hyprland" "gtk"];
      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      "org.freedesktop.impl.portal.Settings" = ["gtk"];
    };
  };

  # Polkit for privilege escalation in Wayland
  security.polkit.enable = true;

  # dconf — required for GTK/libadwaita apps (Nautilus) to read color-scheme
  programs.dconf.enable = true;

  # gvfs — provides trash://, recent://, and mount support for Nautilus
  services.gvfs.enable = true;

  # Brightness/backlight control handled by brightnessctl in packages.nix
}
