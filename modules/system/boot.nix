{
  config,
  lib,
  ...
}: {
  boot.loader.limine = {
    enable = true;
    efiSupport = true;
    maxGenerations = 5;
    enableEditor = true;

    style = {
      # Avoid framebuffer edges left by the mismatched default wallpaper.
      wallpapers = lib.mkForce [];
      backdrop = "191724";
      interface = {
        branding = "NixOS";
        brandingColor = "eb6f92";
        helpColor = "9ccfd8";
        helpColorBright = "c4a7e7";
      };
      graphicalTerminal = {
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
  boot.loader.timeout = 3;

  # Hide boot output during the Plymouth handoff; errors remain in the journal.
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

  # Android x86 emulation requires Intel KVM acceleration.
  boot.kernelModules = ["kvm-intel"];
  # Required for the shutdown/reboot Plymouth splash.
  boot.initrd.systemd.enable = true;

  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };

  # Release DRM without exposing the VT before Hyprland paints.
  # The leading "-" keeps activation green when no splash is running
  # (plymouth quit exits 1), and the unit is boot-only so nixos-rebuild
  # switch must not re-run it.
  systemd.services.plymouth-quit = {
    restartIfChanged = false;
    serviceConfig.ExecStart = lib.mkForce [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  };
}
