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
    # Decrypted from secrets/secrets.yaml before user creation.
    hashedPasswordFile = config.sops.secrets."users/ryan-hashed-password".path;
  };

  services.fwupd.enable = true;

  # Allow brightnessctl to control the backlight without sudo.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';
}
