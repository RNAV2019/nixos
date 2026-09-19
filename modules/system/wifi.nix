{
  config,
  lib,
  ...
}: let
  # Kept apart from secrets.yaml so that it can be written with the public
  # recipient alone; see README. Until it exists and is tracked, none of this
  # applies and the networks saved under /etc are left to themselves.
  sopsFile = ../../secrets/wifi.yaml;

  # uuid is the one each network was first saved under. The copy written to
  # /run then shadows the one in /etc rather than sitting beside it as a second
  # profile with the same name. No interface is pinned, so the profiles work
  # on whatever the next machine calls its card.
  networks = {
    skymrfdt = {
      ssid = "SKYMRFDT";
      uuid = "e586f906-da0b-4dc1-88fa-540c7f8bd4ba";
      pskVar = "SKYMRFDT_PSK";
    };
    skyp1cf7 = {
      ssid = "SKYP1CF7";
      uuid = "322cf862-d45d-4a91-bdaa-aa2f28878e12";
      pskVar = "SKYP1CF7_PSK";
    };
    ryans-s24-ultra = {
      ssid = "Ryans S24 Ultra";
      uuid = "8f34c490-ead7-4412-a726-13ec69a4b3e5";
      pskVar = "RYANS_S24_ULTRA_PSK";
    };
  };

  # envsubst fills the PSK in from the decrypted environment file.
  wpaProfile = _: net: {
    connection = {
      id = net.ssid;
      inherit (net) uuid;
      type = "wifi";
    };
    wifi = {
      mode = "infrastructure";
      inherit (net) ssid;
    };
    wifi-security = {
      key-mgmt = "wpa-psk";
      psk = "$" + net.pskVar;
    };
    ipv4.method = "auto";
    ipv6 = {
      method = "auto";
      addr-gen-mode = "default";
    };
  };
in
  lib.mkIf (builtins.pathExists sopsFile) {
    # Root-only: only the ensure-profiles unit reads it.
    sops.secrets.wifi-env = {inherit sopsFile;};

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [config.sops.secrets.wifi-env.path];
      profiles = lib.mapAttrs wpaProfile networks;
    };
  }
