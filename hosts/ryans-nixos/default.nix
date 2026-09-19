# Panther Lake laptop with a 1920x1200 Samsung OLED. Everything that is true of
# this machine and not of the next one lives here; modules/system and home are
# shared by every host.
{...}: {
  imports = [
    ./hardware-configuration.nix
    ./sof-sdw-ptl-rt721.nix
  ];

  # Kept out of hardware-configuration.nix, which nixos-generate-config
  # overwrites without it.
  hardware.cpu.intel.npu.enable = true;

  home-manager.users.ryan = {
    # 1920x1200 across 300 mm is 163 DPI, which sits right where a fractional
    # scale is tempting. Resist it: Xwayland and any client without
    # wp-fractional-scale-v1 render at the next integer scale and get
    # resampled, and that blur costs more than the size gains. Scale 1 is
    # pixel-exact; grow font sizes instead.
    desktop.monitors = [
      {
        output = "eDP-1";
        mode = "1920x1200@60";
        position = "0x0";
        scale = 1;
      }
    ];

    # Keep at the release Home Manager was first activated with.
    home.stateVersion = "25.11";
  };

  # Keep at this machine's initial release; changing it alters stateful-data defaults
  system.stateVersion = "26.05";
}
