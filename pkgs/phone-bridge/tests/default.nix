# phone-bridge against a mock kdeconnectd on a private session bus. No real device, daemon or
# network is involved.
{
  runCommand,
  phone-bridge,
  python3,
  dbus,
  systemd,
  coreutils,
  gnugrep,
  jq,
}: let
  py = python3.withPackages (ps: [ps.dbus-fast]);
in
  runCommand "phone-bridge-tests" {
    nativeBuildInputs = [phone-bridge py dbus systemd coreutils gnugrep jq];
  } ''
    export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR
    cat > bus.conf <<XML
    <busconfig><type>session</type><listen>unix:tmpdir=$TMPDIR</listen><auth>EXTERNAL</auth>
    <policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/><allow user="*"/></policy></busconfig>
    XML
    dbus-daemon --config-file=bus.conf --print-address --fork --print-pid > bus.out
    export DBUS_SESSION_BUS_ADDRESS=$(head -n1 bus.out)
    trap "kill $(sed -n 2p bus.out)" EXIT

    python ${./mock-kdeconnectd.py} $TMPDIR/calls.log &
    until busctl --user list | grep -q org.mock.Control; do sleep 0.2; done
    ctl() { busctl --user call org.mock.Control /control org.mock.Control Apply s "$1" >/dev/null; }

    phone-bridge events > events.out &
    sleep 1
    ctl '{"op":"device","id":"s24","name":"Galaxy S24 Ultra","type":"smartphone","battery":{"charge":78,"charging":false}}'
    ctl '{"op":"notify","dev":"s24","id":"n1","app":"WhatsApp","title":"Maya","text":"Dinner?"}'
    ctl '{"op":"notify","dev":"s24","id":"n2","app":"Quiet","title":"Ongoing","text":"x","silent":true}'
    ctl '{"op":"battery","dev":"s24","charge":14,"charging":true}'
    ctl '{"op":"cellular","dev":"s24","type":"5G","strength":3}'
    ctl '{"op":"device","id":"px8","name":"Pixel 8","paired":false,"pairRequested":true,"verification":"a1b2c3d4"}'
    ctl '{"op":"device","id":"far","name":"Laptop","type":"laptop","paired":false,"reachable":true}'
    sleep 1
    last=$(tail -n1 events.out)
    echo "$last" | jq -e '.daemon == true' >/dev/null
    echo "$last" | jq -e '[.devices[].id] == ["px8","s24"]' >/dev/null
    echo "$last" | jq -e '.devices[] | select(.id=="s24") | .battery == {"charge":14,"charging":true} and .link == "Wi-Fi"' >/dev/null
    echo "$last" | jq -e '.devices[] | select(.id=="s24") | .cellular == {"type":"5G","strength":3}' >/dev/null
    echo "$last" | jq -e '.devices[] | select(.id=="s24") | [.notifications[].title] == ["Maya"]' >/dev/null
    echo "$last" | jq -e '.devices[] | select(.id=="px8") | .pairRequested and .verification == "a1b2c3d4" and .cellular == null' >/dev/null

    ctl '{"op":"unnotify","dev":"s24","id":"n1"}'
    ctl '{"op":"device","id":"s24","reachable":false}'
    sleep 1
    tail -n1 events.out | jq -e '[.devices[].id] == ["px8"]' >/dev/null

    # The calls the panel makes are plain busctl calls the mock logs.
    busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/px8 org.kde.kdeconnect.device acceptPairing
    grep -qx "px8 device.acceptPairing" calls.log
    busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/s24/share org.kde.kdeconnect.device.share shareUrls as 2 file:///a file:///b
    grep -qx "s24 share.shareUrls file:///a file:///b" calls.log
    busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/s24/sftp org.kde.kdeconnect.device.sftp startBrowsing | grep -qx "b true"
    touch "$out"
  ''
