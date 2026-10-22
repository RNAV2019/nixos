# modules/system/wifi.nix on the iwd backend, against hostapd on mac80211_hwsim:
# the generated iwd files, WPA2-PSK, WPA3-SAE, and eduroam's PEAP/MSCHAPv2 through
# a separate RADIUS server, with a stand-in PKI shaped like Warwick's (root,
# intermediate, leaf eap.warwick.ac.uk). Also checks the traps wifi.nix works
# around: the system CA bundle, iwd's 5s handshake limit and its retry storms.
# Run: nix build .#checks.x86_64-linux.wifi-iwd -L
{pkgs}: let
  # Stand-ins for the sops env file. The eduroam password has the characters
  # most likely to trip iwd's settings parser.
  env = {
    SKYMRFDT_PSK = "sky-test-passphrase";
    RYANS_S24_ULTRA_PSK = "s24-test-passphrase";
    CHARTER_AVENUE_PSK = "charter-test-passphrase";
    EDUROAM_IDENTITY = "u1234567@warwick.ac.uk";
    EDUROAM_PASSWORD = "p@ss w0rd;#x=1";
  };

  pki = pkgs.runCommand "wifi-iwd-test-pki" {nativeBuildInputs = [pkgs.openssl];} ''
    mkdir $out && cd $out
    ext() { printf '%s\n' "$@" > ext.cnf; }
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=Test Root" \
      -keyout root.key -out root.pem \
      -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign,cRLSign
    openssl req -newkey rsa:2048 -nodes -subj "/CN=Test Intermediate" -keyout int.key -out int.csr
    ext basicConstraints=critical,CA:TRUE,pathlen:0 keyUsage=critical,keyCertSign,cRLSign
    openssl x509 -req -in int.csr -CA root.pem -CAkey root.key -CAcreateserial -days 3650 \
      -extfile ext.cnf -out int.pem
    for name in eap.warwick.ac.uk eap.evil.example; do
      openssl req -newkey rsa:2048 -nodes -subj "/CN=$name" -keyout $name.key -out $name.csr
      ext subjectAltName=DNS:$name extendedKeyUsage=serverAuth
      openssl x509 -req -in $name.csr -CA int.pem -CAkey int.key -CAcreateserial -days 3650 \
        -extfile ext.cnf -out leaf.pem
      # The server sends its leaf and the intermediate, not the root.
      cat leaf.pem int.pem > $name.chain.pem
    done
    rm -f *.csr *.srl ext.cnf leaf.pem
  '';

  # Laid out like eduroam-ca.pem: the server's root plus an unrelated one.
  pinnedCa = pkgs.runCommand "pinned-ca.pem" {} ''
    cat ${pki}/root.pem ${../modules/system/eduroam-ca.pem} > $out
  '';
  bundleCa = pkgs.runCommand "bundle-ca.pem" {} ''
    cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ${pki}/root.pem > $out
  '';

  psk = ssid: extra: ''
    interface=wlan0
    driver=nl80211
    ssid=${ssid}
    hw_mode=g
    channel=6
    wpa=2
    rsn_pairwise=CCMP
    ${extra}
  '';
  apConfigs = {
    home = psk "vodafone6EE270" ''
      wpa_key_mgmt=WPA-PSK
      wpa_passphrase=${env.CHARTER_AVENUE_PSK}
    '';
    # WPA3-only (SAE), as a Samsung hotspot can be set to; the profile says wpa-psk.
    # Also tests a file name with spaces.
    phone = psk "Ryans S24 Ultra" ''
      wpa_key_mgmt=SAE
      ieee80211w=2
      sae_password=${env.RYANS_S24_ULTRA_PSK}
    '';
    eduroam = ''
      interface=wlan0
      driver=nl80211
      ssid=eduroam
      hw_mode=g
      channel=1
      ieee8021x=1
      wpa=2
      wpa_key_mgmt=WPA-EAP
      rsn_pairwise=CCMP
      own_ip_addr=127.0.0.1
      nas_identifier=test-ap
      auth_server_addr=127.0.0.1
      auth_server_port=1812
      auth_server_shared_secret=testing123
    '';
    # Through slowRadius, which sits on the first answer of each login.
    eduroam-slow = builtins.replaceStrings ["auth_server_port=1812"] ["auth_server_port=18120"] apConfigs.eduroam;
  };

  radius = server: ''
    driver=none
    interface=radius0
    radius_server_clients=${pkgs.writeText "radius-clients" "127.0.0.1/32 testing123\n"}
    radius_server_auth_port=1812
    eap_server=1
    eap_user_file=${pkgs.writeText "eap-users" ''
      "${env.EDUROAM_IDENTITY}" PEAP
      "${env.EDUROAM_IDENTITY}" MSCHAPV2 "${env.EDUROAM_PASSWORD}" [2]
    ''}
    server_cert=${pki}/${server}.chain.pem
    private_key=${pki}/${server}.key
  '';

  # A RADIUS relay on 18120 that holds the first request of each login (no
  # State attribute yet) and its retransmissions for 12s, as Warwick's server
  # does after a resume, then relays everything at once.
  slowRadius = pkgs.writeScript "slow-radius" ''
    #!${pkgs.python3}/bin/python3
    import select, socket, time

    srv = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    srv.bind(("127.0.0.1", 18120))
    up = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    up.connect(("127.0.0.1", 1812))
    held, until, client = [], 0.0, None

    def has_state(pkt):
        i = 20
        while i + 2 <= len(pkt) and pkt[i + 1] >= 2:
            if pkt[i] == 24:
                return True
            i += pkt[i + 1]
        return False

    while True:
        ready, _, _ = select.select([srv, up], [], [], 0.1)
        for s in ready:
            if s is srv:
                pkt, client = srv.recvfrom(65535)
                if not held and not has_state(pkt) and time.monotonic() >= until:
                    until = time.monotonic() + 12
                held.append(pkt)
            else:
                srv.sendto(up.recv(65535), client)
        if held and time.monotonic() >= until:
            for pkt in held:
                up.send(pkt)
            held = []
  '';

  confs = pkgs.linkFarm "wifi-iwd-test-confs" (pkgs.lib.mapAttrsToList (n: v: {
      name = "${n}.conf";
      path = pkgs.writeText "${n}.conf" v;
    })
    (apConfigs
      // {
        radius-warwick = radius "eap.warwick.ac.uk";
        radius-evil = radius "eap.evil.example";
      }));
in
  pkgs.testers.runNixOSTest {
    name = "wifi-iwd";

    nodes.machine = {lib, ...}: {
      imports = [
        ../modules/system/wifi.nix
        # wifi.nix only reads .path from sops; point it at the stand-in env file.
        {
          options.sops.secrets = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              freeformType = lib.types.attrsOf lib.types.anything;
              options.path = lib.mkOption {default = "/etc/wifi-test.env";};
            });
            default = {};
          };
        }
      ];

      # The laptop's kernel: the CA bundle result depends on its X.509 parser.
      boot.kernelPackages = pkgs.linuxPackages_latest;
      # Two radios: wlan0 for hostapd, wlan1 for iwd.
      boot.kernelModules = ["mac80211_hwsim"];

      networking.networkmanager = {
        enable = true;
        wifi.backend = "iwd";
        logLevel = "INFO";
        unmanaged = ["interface-name:wlan0"];
      };
      systemd.services.iwd.serviceConfig.ExecStart = ["" "${pkgs.iwd}/libexec/iwd --nophys phy0"];

      environment.etc."wifi-test.env" = {
        mode = "0400";
        text = lib.concatStrings (lib.mapAttrsToList (n: v: "${n}=\"${v}\"\n") env);
      };
      # dnsmasq on wlan0 hands out the leases.
      networking.firewall.enable = false;

      environment.systemPackages = [pkgs.hostapd pkgs.dnsmasq pkgs.iw pkgs.iproute2];
    };

    testScript = ''
      import time

      CONFS = "${confs}"
      EDUROAM_FILE = "/var/lib/iwd/eduroam.8021x"
      STATE = "nmcli -g GENERAL.STATE,GENERAL.CONNECTION device show wlan1"
      aps = 0

      def now():
          return int(machine.succeed("date +%s"))

      def start_ap(name, radius=None, slow=False):
          global aps
          aps += 1
          n = aps
          if radius:
              machine.succeed(f"systemd-run --unit=radius-{n} hostapd {CONFS}/radius-{radius}.conf")
          if slow:
              machine.succeed(f"systemd-run --unit=slow-{n} ${slowRadius}")
          # A fresh BSSID each time, so iwd never takes this AP for the previous one.
          machine.succeed(f"ip link set wlan0 down && ip link set wlan0 address 02:00:00:00:aa:{n:02x}")
          machine.succeed(f"systemd-run --unit=ap-{n} hostapd {CONFS}/{name}.conf")
          machine.wait_until_succeeds(f"systemctl is-active ap-{n} && iw dev wlan0 info | grep -q 'type AP'", timeout=30)
          machine.succeed("ip addr replace 192.168.77.1/24 dev wlan0")
          machine.succeed("iwctl station wlan1 scan || true")
          return n

      def stop_ap(n):
          machine.succeed(f"systemctl stop ap-{n} radius-{n} slow-{n} 2>/dev/null || true")
          machine.wait_until_succeeds(f"! {STATE} | grep -q '^100'", timeout=30)

      def connected(conn, timeout):
          start = time.monotonic()
          machine.wait_until_succeeds(f"{STATE} | tr '\\n' ' ' | grep -q '^100 (connected) {conn} '", timeout=timeout)
          return time.monotonic() - start

      def refused(n, since):
          # The server got as far as offering PEAP, then iwd gave up on the login.
          machine.wait_until_succeeds(f"journalctl -u radius-{n} | grep -q 'PROPOSED-METHOD vendor=0 method=25'", timeout=90)
          machine.wait_until_succeeds(f"journalctl -u iwd --since @{since} | grep -q 'event: connect-failed'", timeout=90)
          machine.fail(f"{STATE} | grep -q '^100'")
          print(machine.succeed(f"journalctl -u iwd --since @{since} -o cat | grep -E 'EAP|TLS|cert|handshake|connect-failed' | head -n 8"))

      def set_cacert(path):
          # iwd re-reads a known network's file on each connection attempt.
          machine.succeed(f"sed -i 's|^EAP-PEAP-CACert=.*|EAP-PEAP-CACert={path}|' {EDUROAM_FILE}")
          # Also restarts iwd-eap-backoff, which lifts any pause from the last subtest.
          machine.succeed("systemctl restart iwd")
          machine.wait_until_succeeds("iwctl station wlan1 show", timeout=30)

      machine.wait_for_unit("iwd.service")
      # A oneshot that ends inactive; wait for what it loads.
      machine.wait_until_succeeds("nmcli -g NAME connection show | grep -qx eduroam", timeout=60)
      machine.succeed("ip addr add 192.168.77.1/24 dev wlan0")
      machine.succeed("systemd-run --unit=dhcp dnsmasq -k -i wlan0 -z -p0 --dhcp-leasefile=/tmp/dnsmasq.leases --dhcp-range=192.168.77.10,192.168.77.50,1h")

      with subtest("iwd-provision writes every network, root-only, secrets filled in"):
          for f in ["SKYMRFDT.psk", "vodafone6EE270.psk", "Ryans S24 Ultra.psk", "eduroam.8021x"]:
              machine.succeed(f"test \"$(stat -c '%a %U' '/var/lib/iwd/{f}')\" = '600 root'")
          machine.succeed("! grep -r '\\$' /var/lib/iwd/")
          machine.succeed("grep -qx 'Passphrase=${env.SKYMRFDT_PSK}' /var/lib/iwd/SKYMRFDT.psk")
          machine.succeed(f"grep -qxF 'EAP-PEAP-Phase2-Password=${env.EDUROAM_PASSWORD}' {EDUROAM_FILE}")
          machine.succeed(f"grep -qx 'EAP-PEAP-CACert=${../modules/system/eduroam-ca.pem}' {EDUROAM_FILE}")
          known = machine.succeed("iwctl known-networks list")
          for ssid in ["SKYMRFDT", "vodafone6EE270", "Ryans S24 Ultra", "eduroam"]:
              assert ssid in known, f"{ssid} missing from iwd:\n{known}"
          print(known)

      with subtest("NetworkManager has the declared profiles and mirrors nothing into iwd"):
          names = machine.succeed("nmcli -g NAME,TYPE connection show | grep wireless | sort")
          print(names)
          assert names.count(":802-11-wireless") == 4, names
          machine.succeed("grep -qx 'iwd-config-path=' /etc/NetworkManager/NetworkManager.conf")

      with subtest("home network: WPA2-PSK autoconnects on the declared profile"):
          ap = start_ap("home")
          print(f"connected after {connected('vodafone6EE270', 90):.1f}s")
          machine.succeed("nmcli -g GENERAL.CON-UUID device show wlan1 | grep -qx 5480e3c6-1089-4b52-bd41-91c07fa2e719")
          machine.wait_until_succeeds("ip -4 addr show wlan1 | grep -q 192.168.77.", timeout=30)
          machine.succeed("ping -c1 -W3 192.168.77.1")

      with subtest("NetworkManager sleep and wake reconnects"):
          machine.succeed("busctl call org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Sleep b true")
          machine.wait_until_succeeds(f"! {STATE} | grep -q '^100'", timeout=30)
          machine.succeed("busctl call org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Sleep b false")
          print(f"reconnected after {connected('vodafone6EE270', 60):.1f}s")
          stop_ap(ap)

      with subtest("phone hotspot: WPA3-SAE from a wpa-psk profile"):
          ap = start_ap("phone")
          print(f"connected after {connected('Ryans S24 Ultra', 90):.1f}s")
          machine.succeed("nmcli -g GENERAL.CON-UUID device show wlan1 | grep -qx 8f34c490-ead7-4412-a726-13ec69a4b3e5")
          stop_ap(ap)

      with subtest("eduroam: PEAP/MSCHAPv2 through RADIUS, pinned CA, *.warwick.ac.uk"):
          set_cacert("${pinnedCa}")
          ap = start_ap("eduroam", radius="warwick")
          print(f"connected after {connected('eduroam', 90):.1f}s")
          machine.succeed("nmcli -g GENERAL.CON-UUID device show wlan1 | grep -qx 729969dc-ea03-4dc8-a823-e0f2c8b66a72")
          machine.wait_until_succeeds("ip -4 addr show wlan1 | grep -q 192.168.77.", timeout=30)
          stop_ap(ap)

      with subtest("eduroam: refuses a server outside *.warwick.ac.uk, then backs off"):
          set_cacert("${pinnedCa}")
          since = now()
          ap = start_ap("eduroam", radius="evil")
          refused(ap, since)
          # Left to iwd, a failed login is retried every few seconds, which got Warwick to
          # lock the laptop's MAC out. iwd-eap-backoff: one login, a 2 min pause, one more.
          logins = f"journalctl -u iwd --since @{since} | grep -c 'connect-info, ssid: eduroam'"
          backoff = f"journalctl -u iwd-eap-backoff --since @{since}"
          machine.wait_until_succeeds(f"{backoff} | grep -q 'eduroam failed; autoconnect paused for 2 min'", timeout=30)
          time.sleep(60)
          assert machine.succeed(logins).strip() == "1", "retried during the pause"
          # Resuming waits for iwd's next periodic scan, which backs off to 5 min.
          machine.wait_until_succeeds(f"{backoff} | grep -q 'paused for 4 min'", timeout=480)
          assert machine.succeed(logins).strip() == "2"
          print(machine.succeed(f"{backoff} -o cat"))
          stop_ap(ap)

      with subtest("eduroam: the system CA bundle fails even with the right root in it"):
          set_cacert("${bundleCa}")
          since = now()
          ap = start_ap("eduroam", radius="warwick")
          # iwd rejects the whole file (the kernel won't parse Certum Trusted Network CA 2)
          # and never starts a login.
          machine.wait_until_succeeds(f"journalctl -u iwd --since @{since} | grep -q 'Failed to load ${bundleCa}'", timeout=60)
          time.sleep(15)
          machine.fail(f"journalctl -u radius-{ap} | grep -q 'EAP-STARTED'")
          machine.fail(f"{STATE} | grep -q '^100'")
          stop_ap(ap)

      with subtest("eduroam: a 12s first RADIUS answer passes with MaxHandshakeTime=60 ..."):
          set_cacert("${pinnedCa}")
          ap = start_ap("eduroam-slow", radius="warwick", slow=True)
          print(f"connected after {connected('eduroam', 120):.1f}s")
          stop_ap(ap)

      with subtest("... and fails on iwd's 5s default"):
          machine.succeed("cp --remove-destination \"$(readlink -f /etc/iwd/main.conf)\" /etc/iwd/main.conf")
          machine.succeed("sed -i '/MaxHandshakeTime/d' /etc/iwd/main.conf")
          machine.succeed("systemctl restart iwd")
          machine.wait_until_succeeds("iwctl station wlan1 show", timeout=30)
          since = now()
          ap = start_ap("eduroam-slow", radius="warwick", slow=True)
          refused(ap, since)
          # A login that times out counts too: Cisco controllers exclude a client for those as well.
          machine.wait_until_succeeds(f"journalctl -u iwd-eap-backoff --since @{since} | grep -q 'eduroam failed; autoconnect paused'", timeout=30)
          stop_ap(ap)
    '';
  }
