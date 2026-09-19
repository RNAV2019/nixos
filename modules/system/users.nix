{
  config,
  pkgs,
  ...
}: {
  users.users.ryan = {
    isNormalUser = true;
    description = "ryan";
    # kvm grants passwordless /dev/kvm access for Android emulation.
    extraGroups = ["networkmanager" "wheel" "video" "audio" "kvm"];
    shell = pkgs.fish;
    # From secrets/secrets.yaml, decrypted before user creation. The only
    # thing to restore by hand on new hardware is the age key; see README.
    hashedPasswordFile = config.sops.secrets."users/ryan-hashed-password".path;
  };

  services.fwupd.enable = true;

  # Allow brightnessctl to control the backlight without sudo.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';
}
