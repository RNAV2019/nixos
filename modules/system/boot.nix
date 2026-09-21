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
      # Boot runs before any user theme state exists, so it cannot follow the desktop theme.
      # It is neutral grey on black instead, which sits under both themes, and black is
      # plymouth bgrt's own, so the menu, the splash and Hyprland's first frame all match.
      # The menu only uses a handful of palette slots, so plain grey steps are enough.
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
