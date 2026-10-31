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
    first=$!
    sleep 1
    ctl '{"op":"device","id":"s24","name":"Galaxy S24 Ultra","type":"phone","battery":{"charge":78,"charging":false}}'
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

    # A device of type "phone" (KDE Connect 26.08; older releases say "smartphone"), whose
    # phone sends no mobile report yet.
    ctl '{"op":"device","id":"t1","name":"Test Phone","type":"phone","battery":{"charge":50,"charging":false}}'
    sleep 1
    tail -n1 events.out | jq -e '.devices[] | select(.id=="t1") | .type == "phone" and .cellular == null' >/dev/null

    # Files the shell sends and the phone's storage, as the shell calls them.
    ctl '{"op":"sftp","dev":"t1","grant":false}'
    busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/t1/sftp org.kde.kdeconnect.device.sftp mountAndWait | grep -qx "b false"
    busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/t1/sftp org.kde.kdeconnect.device.sftp getMountError | grep -q "Permissions missing: filesystem access"
    ctl '{"op":"sftp","dev":"t1","grant":true,"mount":"/tmp/phone-storage"}'
    busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/t1/sftp org.kde.kdeconnect.device.sftp mountAndWait | grep -qx "b true"
    busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/t1/sftp org.kde.kdeconnect.device.sftp mountPoint | grep -qx 's "/tmp/phone-storage"'

    # Transfers: kdeconnectd's job tracker asks whoever owns org.kde.JobViewServer for a view
    # per job; the mock plays that tracker. Only kdeconnect's jobs reach the stream.
    busctl --user list | grep -q "org.kde.JobViewServer"
    transfers() { jq -c 'select(.event=="transfer") | .transfer' events.out; }

    ctl '{"op":"job_start","job":"up","dev":"t1","direction":"out","files":["a.jpg"],"total":1000}'
    sleep 0.4
    ctl '{"op":"job_update","job":"up","processed":250,"percent":25}'
    sleep 0.4
    transfers | jq -e 'select(.direction=="out" and .state=="in_progress" and .percent==25 and .bytes==250 and .total_bytes==1000 and .files==["a.jpg"] and .peer=="Test Phone")' >/dev/null
    # A send with nothing to say yet has no percent: the shell draws it as indeterminate.
    transfers | jq -e 'select(.direction=="out" and .state=="in_progress" and .percent==null)' >/dev/null
    ctl '{"op":"job_end","job":"up"}'
    sleep 0.4
    transfers | jq -e 'select(.direction=="out" and .state=="finished" and .percent==100)' >/dev/null

    ctl '{"op":"job_start","job":"down","dev":"t1","direction":"in","files":["IMG_1.jpg"],"total":2000,"dir":"/tmp/Downloads"}'
    sleep 0.4
    # shareReceived for a file the job wrote is not a second arrival; for any other it is.
    ctl '{"op":"share_received","dev":"t1","url":"file:///tmp/Downloads/IMG_1.jpg"}'
    ctl '{"op":"share_received","dev":"t1","url":"file:///tmp/Downloads/loose.pdf"}'
    ctl '{"op":"job_end","job":"down"}'
    sleep 0.4
    transfers | jq -e 'select(.direction=="in" and .state=="finished" and .saved_paths==["/tmp/Downloads/IMG_1.jpg"] and .peer=="Test Phone")' >/dev/null
    transfers | jq -e 'select(.state=="finished" and .saved_paths==["/tmp/Downloads/loose.pdf"])' >/dev/null
    [ "$(transfers | jq -c 'select(.saved_paths==["/tmp/Downloads/IMG_1.jpg"] and .state=="finished")' | wc -l)" = 1 ]

    ctl '{"op":"job_start","job":"fail","dev":"t1","direction":"out","files":["b.jpg"],"total":10}'
    sleep 0.3
    ctl '{"op":"job_end","job":"fail","code":1}'
    ctl '{"op":"job_start","job":"bad","dev":"t1","direction":"out","files":["c.jpg"],"total":10}'
    sleep 0.3
    ctl '{"op":"job_end","job":"bad","code":9,"message":"Timeout waiting for receiver to connect"}'
    sleep 0.4
    transfers | jq -e 'select(.files==["b.jpg"] and .state=="cancelled")' >/dev/null
    transfers | jq -e 'select(.files==["c.jpg"] and .state=="failed" and .error=="Timeout waiting for receiver to connect")' >/dev/null

    # Another app's job is accepted and not shown.
    ctl '{"op":"job_start","job":"other","dev":"t1","direction":"out","files":["z.jpg"],"desktop":"org.kde.dolphin"}'
    sleep 0.3
    ctl '{"op":"job_end","job":"other"}'
    sleep 0.3
    [ "$(transfers | jq -c 'select(.files==["z.jpg"])' | wc -l)" = 0 ]

    # A transfer the shell cancels reaches the job as cancelRequested.
    ctl '{"op":"job_start","job":"stop","dev":"t1","direction":"out","files":["d.jpg"]}'
    sleep 0.3
    id=$(transfers | jq -r 'select(.files==["d.jpg"]) | .id' | head -n1)
    busctl --user call org.kde.JobViewServer /JobViewServer org.kde.PhoneBridge cancel s "$id"
    sleep 0.3
    grep -qx "job.cancelRequested stop" calls.log

    # With the name taken, a second bridge says so and still serves the picture; when the
    # first one goes the name goes with it.
    phone-bridge events > second.out 2> second.err &
    second=$!
    sleep 1
    grep -q "owned elsewhere" second.err
    head -n1 second.out | jq -e '.event == "state"' >/dev/null
    kill $second
    kill $first
    sleep 1
    ! busctl --user list | grep -q "org.kde.JobViewServer"
    touch "$out"
  ''
