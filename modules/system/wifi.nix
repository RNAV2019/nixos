{
  config,
  lib,
  ...
}: let
  # Separate from secrets.yaml so it can be written with the public recipient
  # alone. If it is missing, this module does nothing.
  sopsFile = ../../secrets/wifi.yaml;

  # Reusing each network's original uuid makes the /run profile shadow the one
  # in /etc instead of duplicating it. No interface is pinned.
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
