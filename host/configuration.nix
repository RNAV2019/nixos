{ config, pkgs, ... }:

{
  # Grub Bootloader — always shown, no timeout, manual selection required.
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    configurationLimit = 10;
    font = "${pkgs.unifont}/share/fonts/opentype/unifont.otf";
    fontSize = 48;
    gfxmodeEfi = "auto";
    splashImage = null;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = null;

  # Suppress kernel/udev log spam and TTY artefacts; hand off cleanly to Plymouth.
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=false"
    "udev.log_level=3"
    "udev.log_priority=3"
    "vt.global_cursor_default=0"
  ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  # systemd in initrd is required for the shutdown/reboot Plymouth splash.
  boot.initrd.systemd.enable = true;

  # Plymouth splash — custom Rose Pine theme (base #191724) so Plymouth →
  # Hyprland → hyprlock is one continuous colour with no firmware-logo flash.
  boot.plymouth = {
    enable = true;
    theme = "rose-pine";
    themePackages = [
      (pkgs.runCommand "rose-pine-plymouth" {} ''
        mkdir -p $out/share/plymouth/themes/rose-pine
        cp -r ${./plymouth/rose-pine}/. $out/share/plymouth/themes/rose-pine/
      '')
    ];
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.hostName = "nixos";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ryan = {
    isNormalUser = true;
    description = "ryan";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    shell = pkgs.fish;
  };

  # Allow brightnessctl to control backlight without sudo
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"    
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"    
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
