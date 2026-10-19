{
  config,
  pkgs,
  user,
  ...
}: {
  users.users.${user} = {
    isNormalUser = true;
    # The full name; the lock screen reads it from GECOS.
    description = "Ryan Navsaria";
    # kvm grants passwordless /dev/kvm access for Android emulation.
    extraGroups = ["networkmanager" "wheel" "video" "audio" "kvm"];
    shell = pkgs.fish;
    # Decrypted from secrets/secrets.yaml before user creation.
    hashedPasswordFile = config.sops.secrets."users/ryan-hashed-password".path;
  };
}
