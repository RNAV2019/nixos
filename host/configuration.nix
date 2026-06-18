{
  config,
  pkgs,
  lib,
  ...
}: {
  # Limine bootloader — Rose Pine themed, manual selection (no auto-boot).
  boot.loader.limine = {
    enable = true;
    efiSupport = true;
    maxGenerations = 5;
    enableEditor = true;

    style = {
      # Drop the module's default NixOS gray wallpaper — its dimensions don't
      # match the panel and leave uncleared framebuffer slices at screen edges.
      # Solid backdrop fills the whole screen cleanly.
      wallpapers = lib.mkForce [];
      backdrop = "191724";
      interface = {
        branding = "NixOS";
        brandingColor = "eb6f92";
        helpColor = "9ccfd8";
        helpColorBright = "c4a7e7";
      };
      graphicalTerminal = {
        font.scale = "2x2";
        background = "191724";
        foreground = "e0def4";
        brightBackground = "6e6a86";
        brightForeground = "e0def4";
        palette = "191724;eb6f92;9ccfd8;f6c177;31748f;c4a7e7;9ccfd8;e0def4";
        brightPalette = "6e6a86;eb6f92;9ccfd8;f6c177;31748f;c4a7e7;9ccfd8;e0def4";
      };
    };
  };
  boot.loader.efi.canTouchEfiVariables = true;
  # Very large timeout effectively waits for manual selection (Limine has no "no timeout").
  boot.loader.timeout = 1000000;

  # Suppress kernel/udev log spam and TTY artefacts; hand off cleanly to Plymouth.
  # consoleLogLevel 0 hides even kernel errors from the console (they remain in
  # the journal); systemd.show_status=false covers stage-2, notably shutdown.
  boot.kernelParams = [
    "quiet"
    "splash"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=false"
    "systemd.show_status=false"
    "udev.log_level=3"
    "udev.log_priority=3"
    "vt.global_cursor_default=0"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  # systemd in initrd is required for the shutdown/reboot Plymouth splash.
  boot.initrd.systemd.enable = true;

  # Hyprland → hyprlock is one continuous colour with no firmware-logo flash.
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
    extraGroups = ["networkmanager" "wheel" "video" "audio"];
    shell = pkgs.fish;
  };

  services.fwupd.enable = true;

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
