{ config, pkgs, ... }:

{
  # Grub Bootloader — hidden by default; hold Shift at boot to access the menu.
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    configurationLimit = 10;
    font = "${pkgs.unifont}/share/fonts/opentype/unifont.otf";
    fontSize = 48;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  # Suppress kernel/udev log spam and TTY artefacts; hand off cleanly to Plymouth.
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
    "udev.log_priority=3"
    "vt.global_cursor_default=0"
    "fbcon=nodefer"
  ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  # systemd in initrd is required for the shutdown/reboot Plymouth splash.
  boot.initrd.systemd.enable = true;

  # Plymouth splash. `bgrt` shows the firmware logo on black — neutral against
  # Rose Pine. TODO: ship a custom Rose Pine theme package and switch to it.
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
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
