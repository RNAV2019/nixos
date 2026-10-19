# Panther Lake laptop with a Samsung OLED. Machine-specific settings only;
# modules/system and home are shared by every host.
{user, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./platform.nix
    ./sof-sdw-ptl-rt721.nix
  ];

  # Quick Share and AirDrop (`nearby`). The Intel BE211 runs AWDL only in
  # omdrop-owl's exclusive mode: Wi-Fi drops while an AirDrop window is open.
  # Quick Share is visible from boot (android_visible_on_start), so the laptop
  # is discoverable without opening the quickshell panel. Notifications are off:
  # the shell's Sharing Pill (panel shut) and Sharing Panel (open) ask for consent
  # and show arrivals themselves, so a toast would only duplicate them.
  services.nearby = {
    enable = true;
    inherit user;
    settings.notifications = false;
    settings.android_visible_on_start = true;
  };

  home-manager.users.${user} = {
    desktop.monitors = [
      {
        output = "eDP-1";
        mode = "2880x1800@120";
        position = "0x0";
        scale = 1.33;
      }
    ];

    # Keep at the release Home Manager was first activated with.
    home.stateVersion = "25.11";
  };

  # Keep at this machine's initial release; changing it alters stateful-data defaults
  system.stateVersion = "26.05";
}
