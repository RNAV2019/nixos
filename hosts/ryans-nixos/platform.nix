# This laptop's hardware: Panther Lake graphics, the Ideapad keyboard, the OLED panel,
# the backlight and the battery charge mode. Settings any machine would want stay in
# modules/system.
{pkgs, ...}: {
  # Panther Lake Xe3 needs a current kernel; there is no i915 fallback
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [intel-media-driver vpl-gpu-rt];
  };

  # Copilot key (Shift+Meta+F23) becomes Ctrl. PrtSc (Shift+Meta+S) and the Ideapad
  # screenshot button (which keyd rewrites to F16) become sysrq, Hyprland's Print.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        main."leftshift+leftmeta+f23" = "layer(control)";
        main."leftshift+leftmeta+s" = "sysrq";
        main.f16 = "sysrq";
      };
    };
  };

  # Mark keyd's virtual keyboard as internal so libinput's disable-while-typing
  # still pairs it with the touchpad.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd virtual keyboard]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

  # thermald --adaptive applies the firmware's DPTF tables and pins MMIO PL1 to
  # 10 W, holding all-core clocks under 1 GHz, so it stays off. The kernel's
  # int340x driver and hardware TCC still handle thermal protection.
  services.thermald.enable = false;

  # The OLED's subpixel layout is unknown, so grayscale AA avoids colour fringes.
  fonts.fontconfig.subpixel.rgba = "none";

  services.fwupd.enable = true;

  # Allow brightnessctl to control the backlight without sudo.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"

    # Let the shell's charging tile pick the battery's charge mode (Fast, Standard, Long_Life).
    # ideapad-laptop adds charge_types to BAT0 as a power-supply extension, which can land
    # after the "add" event, so the attribute is matched on change too and only once it exists.
    ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_types}=="?*", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/power_supply/%k/charge_types"
    ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_types}=="?*", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/power_supply/%k/charge_types"
  '';
}
