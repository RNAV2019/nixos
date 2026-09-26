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

  # Warwick's settings; see their eduroam "other devices" page. The bundle holds
  # their root, so the domain match is what stops any public CA's cert passing.
  eduroam = {
    connection = {
      id = "eduroam";
      uuid = "729969dc-ea03-4dc8-a823-e0f2c8b66a72";
      type = "wifi";
    };
    wifi = {
      mode = "infrastructure";
      ssid = "eduroam";
    };
    wifi-security.key-mgmt = "wpa-eap";
    "802-1x" = {
      eap = "peap";
      phase2-auth = "mschapv2";
      identity = "$EDUROAM_IDENTITY";
      password = "$EDUROAM_PASSWORD";
      ca-cert = "/etc/ssl/certs/ca-certificates.crt";
      domain-suffix-match = "warwick.ac.uk";
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
      profiles = lib.mapAttrs wpaProfile networks // {inherit eduroam;};
    };
  }
