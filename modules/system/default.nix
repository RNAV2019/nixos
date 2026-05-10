{ config, pkgs, hyprland, ... }:
{
  # Locale, timezone and keymaps
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT    = "en_GB.UTF-8";
    LC_MONETARY       = "en_GB.UTF-8";
    LC_NAME           = "en_GB.UTF-8";
    LC_NUMERIC        = "en_GB.UTF-8";
    LC_PAPER          = "en_GB.UTF-8";
    LC_TELEPHONE      = "en_GB.UTF-8";
    LC_TIME           = "en_GB.UTF-8";
  };
  console.keyMap = "uk";

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
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

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };
  services.blueman.enable = true;

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
    package = hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  # Override nixpkgs xdg-desktop-portal-hyprland with the flake version
  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal-hyprland = hyprland.packages.${prev.system}.xdg-desktop-portal-hyprland;
    })
  ];

  # UWSM
  programs.uwsm = {
    enable = true;
    waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment = "Hyprland compositor managed by UWSM";
      binPath = "/run/current-system/sw/bin/Hyprland";
    };
  };

  # greetd display manager — autologin as ryan, hyprlock handles the lock screen
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
      initial_session = {
        command = "uwsm start hyprland-uwsm.desktop";
        user = "ryan";
      };
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
  ];

  # Fingerprint reader
  services.fprintd.enable = true;

  # PAM fingerprint auth for sudo, login, lock screen
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.login.fprintAuth = true;
  security.pam.services.greetd.fprintAuth = true;
  security.pam.services.hyprlock.fprintAuth = true;

  # Power profiles daemon
  services.power-profiles-daemon.enable = true;

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
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Polkit for privilege escalation in Wayland
  security.polkit.enable = true;

  # Brightness/backlight control handled by brightnessctl in packages.nix

}
