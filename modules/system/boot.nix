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
      # Boot can't follow the runtime theme, so use neutral greys on black, which
      # matches the plymouth splash and Hyprland's first frame.
      backdrop = "000000";
      interface = {
        branding = "NixOS";
        brandingColor = "ffffff";
        helpColor = "8c8c8c";
        helpColorBright = "d6d6d6";
      };
      graphicalTerminal = {
        background = "000000";
        foreground = "d6d6d6";
        brightBackground = "3f3f3f";
        brightForeground = "ffffff";
        palette = "000000;8c8c8c;a6a6a6;bfbfbf;8c8c8c;a6a6a6;bfbfbf;d6d6d6";
        brightPalette = "3f3f3f;a6a6a6;bfbfbf;d6d6d6;a6a6a6;bfbfbf;d6d6d6;ffffff";
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

  # Release DRM without exposing the VT before Hyprland paints. "-" tolerates
  # plymouth quit exiting 1 when no splash is running; boot-only, so no restart.
  systemd.services.plymouth-quit = {
    restartIfChanged = false;
    serviceConfig.ExecStart = lib.mkForce [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  };
}
