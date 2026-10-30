# What the Quickshell island needs from udisks2: the removable filesystems as JSON, and
# mount / eject with errors it can word ("target is busy" and who holds it).
{
  writeTextFile,
  python3,
  runCommand,
  lib,
  glib,
  systemd,
  udisks,
}: let
  path = lib.makeBinPath [glib systemd udisks];
  script = writeTextFile {
    name = "island-usb";
    executable = true;
    destination = "/bin/island-usb";
    text = "#!${python3}/bin/python3 -I\n" + lib.replaceStrings ["@path@"] [path] (builtins.readFile ./island-usb.py);
    checkPhase = ''
      ${python3}/bin/python3 -m py_compile $target
    '';
  };
in
  script.overrideAttrs (old: {
    passthru =
      (old.passthru or {})
      // {
        tests = runCommand "island-usb-tests" {nativeBuildInputs = [python3];} ''
          export HOME=$TMPDIR
          ISLAND_USB_BIN=${script}/bin/island-usb FIXTURES=${./tests/fixtures} \
            python3 ${./tests/test_island_usb.py} -v
          touch $out
        '';
      };
  })
