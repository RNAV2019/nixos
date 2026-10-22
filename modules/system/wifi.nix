{
  config,
  lib,
  pkgs,
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
    charter-avenue = {
      ssid = "vodafone6EE270";
      uuid = "5480e3c6-1089-4b52-bd41-91c07fa2e719";
      pskVar = "CHARTER_AVENUE_PSK";
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
      # Warwick's APs sometimes ignore association or RADIUS goes quiet for a
      # while. Keep retrying rather than blocking autoconnect after 4 failures.
      # wpa_supplicant only: iwd ignores this (see iwd-eap-backoff).
      autoconnect-retries = 0;
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
      # Warwick's RADIUS can take 12s+ to answer the first EAP after a resume,
      # so a full PEAP exchange overruns NetworkManager's 25s default and is
      # torn down just before it would have succeeded.
      auth-timeout = 60;
    };
    ipv4.method = "auto";
    ipv6 = {
      method = "auto";
      addr-gen-mode = "default";
    };
  };

  # With the iwd backend, iwd authenticates from its own files in /var/lib/iwd and
  # NetworkManager only matches them to the profiles above for IP config. It
  # refuses an 802.1x network iwd has no file for, and its own conversion copies
  # ca-cert as-is, so the files are written here instead.
  useIwd = config.networking.networkmanager.wifi.backend == "iwd";

  # iwd checks the server chain in the kernel keyring, which rejects one root in
  # the system bundle (Certum Trusted Network CA 2) and so every handshake. This
  # holds Warwick's root, Sectigo R46, plus the three roots that cross-sign it
  # (USERTrust RSA, COMODO RSA, AAA Certificate Services): unlike OpenSSL, iwd
  # needs the issuer of whichever certificate tops the chain the server sends.
  eduroamCa = ./eduroam-ca.pem;

  # File names are the SSID (letters, digits, spaces, '-' and '_' only).
  iwdNetworks =
    lib.mapAttrs' (_: net:
      lib.nameValuePair "${net.ssid}.psk" ''
        [Security]
        Passphrase=${"$" + net.pskVar}
      '')
    networks
    // {
      # domain-suffix-match's equivalent: '*' matches one or more labels.
      "eduroam.8021x" = ''
        [Security]
        EAP-Method=PEAP
        EAP-Identity=$EDUROAM_IDENTITY
        EAP-PEAP-CACert=${eduroamCa}
        EAP-PEAP-ServerDomainMask=*.warwick.ac.uk
        EAP-PEAP-Phase2-Method=MSCHAPV2
        EAP-PEAP-Phase2-Identity=$EDUROAM_IDENTITY
        EAP-PEAP-Phase2-Password=$EDUROAM_PASSWORD
      '';
    };
in
  lib.mkIf (builtins.pathExists sopsFile) (lib.mkMerge [
    {
      # Root-only: only the ensure-profiles and iwd-provision units read it.
      sops.secrets.wifi-env = {inherit sopsFile;};

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [config.sops.secrets.wifi-env.path];
        profiles = lib.mapAttrs wpaProfile networks // {inherit eduroam;};
      };
    }

    (lib.mkIf useIwd {
      # Off, so NetworkManager never overwrites the files below with its own
      # conversion of the profiles (see eduroamCa).
      networking.networkmanager.settings.main.iwd-config-path = "";

      # iwd has no auth-timeout: EAP and the 4-way handshake together get this
      # long (default 5s), and Warwick's RADIUS can stall for 20s+ after a resume.
      networking.wireless.iwd.settings.EAPoL.MaxHandshakeTime = 60;
      # After a failed attempt iwd skips that access point for 60s by default, so
      # one failure at home (one AP) meant a minute offline. wpa_supplicant waits 10s.
      networking.wireless.iwd.settings.Blacklist.InitialTimeout = 10;
      # Logs the TLS handshake and why a server certificate was rejected at info
      # level; without it iwd only says "bad_certificate". Drop once eduroam is stable.
      systemd.services.iwd.environment.IWD_TLS_DEBUG = "1";

      # Rewritten on every iwd start, so edits made through iwctl don't stick.
      systemd.services.iwd-provision = {
        description = "Write the declared Wi-Fi networks into iwd's state directory";
        wantedBy = ["iwd.service"];
        before = ["iwd.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          EnvironmentFile = config.sops.secrets.wifi-env.path;
          UMask = "0077";
        };
        script =
          ''
            mkdir -p /var/lib/iwd
          ''
          + lib.concatStrings (lib.mapAttrsToList (name: text: ''
              ${pkgs.envsubst}/bin/envsubst -i ${pkgs.writeText "iwd-network" text} > ${lib.escapeShellArg "/var/lib/iwd/${name}"}
            '')
            iwdNetworks);
      };

      # After a failed 802.1X login iwd retries on the next scan, every few
      # seconds, for as long as the network is in range: it has no back-off for
      # these and NetworkManager's autoconnect-retries don't apply to it. One bad
      # CA file became ~70 logins in an hour, and Warwick's controllers and ISE
      # locked the MAC out for ~30 min. So after each failed login this turns
      # autoconnect off for that network for 2 min, doubling to 30, until a
      # connection succeeds. Connecting by hand works throughout.
      systemd.services.iwd-eap-backoff = {
        description = "Pause iwd autoconnect to a network after failed 802.1X logins";
        wantedBy = ["iwd.service"];
        after = ["iwd.service"];
        partOf = ["iwd.service"];
        path = [pkgs.iwd pkgs.systemd pkgs.coreutils];
        serviceConfig = {
          Restart = "always";
          # Survives a restart, so a pause can't outlive this service.
          RuntimeDirectory = "iwd-eap-backoff";
          RuntimeDirectoryPreserve = true;
        };
        script = ''
          cd "$RUNTIME_DIRECTORY"
          set_auto() {
            iwctl known-networks "$1" set-property AutoConnect "$2" ||
              echo "couldn't set AutoConnect=$2 on $1"
          }
          declare -A level resume
          save() { if ((''${#resume[@]})); then printf '%s\n' "''${!resume[@]}"; fi >paused; }

          # iwd keeps AutoConnect=false in the network's file, so undo leftovers.
          touch paused
          while IFS= read -r s; do set_auto "$s" yes; done <paused
          save

          ssid="" counted=""
          while :; do
            if IFS= read -r -t 5 line; then
              case $line in
                "event: connect-info, ssid: "*)
                  ssid=''${line#event: connect-info, ssid: }
                  ssid=''${ssid%, bss: *}
                  counted=""
                  ;;
                "event: state, old: "*", new: connected")
                  [[ -n $ssid ]] && unset "level[$ssid]"
                  ;;
                # The first is iwd giving up (e.g. bad certificate), the second the
                # server ending it straight after an identity (e.g. a reject).
                *"connect-failed, reason: 23"* | "EAP negotiation stopped"*)
                  [[ -n $ssid && -z $counted ]] || continue
                  counted=1
                  n=''${level[$ssid]:-0}
                  mins=$((n >= 4 ? 30 : 2 << n))
                  level[$ssid]=$((n + 1))
                  resume[$ssid]=$(($(date +%s) + mins * 60))
                  save
                  set_auto "$ssid" no
                  echo "login to $ssid failed; autoconnect paused for $mins min"
                  ;;
              esac
            elif (($? <= 128)); then
              exit 1 # journalctl ended; restart
            fi
            now=$(date +%s)
            for s in "''${!resume[@]}"; do
              t=''${resume[$s]}
              ((now >= t)) || continue
              unset "resume[$s]"
              save
              set_auto "$s" yes
              echo "autoconnect to $s resumed"
            done
          done < <(journalctl -f -n0 -u iwd.service -o cat)
        '';
      };
    })
  ])
