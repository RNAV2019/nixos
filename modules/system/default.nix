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
  hardware.pulseaudio.enable = false;

  # Hyprland at system level
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  # UWSM
  programs.uwsm = {
    enable = true;
    waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment = "Hyprland compositor managed by UWSM";
      binPath = "/run/current-system/sw/bin/Hyprland";
    };
  };

  # SDDM display manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "breeze";
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
  
  # Power profiles daemon
  services.power-profiles-daemon.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-color-emoji
  ];

  # XDG portal for file pickers, screen sharing etc
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  };

  # Polkit for privilege escalation in Wayland
  security.polkit.enable = true;

  # Brightness/backlight control handled by brightnessctl in packages.nix

  # Swap#
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 8 * 1024;
  }];
}
