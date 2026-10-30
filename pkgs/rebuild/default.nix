# `rebuild`: builds and switches this system like `sudo nixos-rebuild switch --flake` did,
# showing nix-output-monitor in the terminal and telling the Quickshell island how it goes.
{
  writeTextFile,
  python3,
  runCommand,
  lib,
  nix-output-monitor,
  dix,
  coreutils,
  repoDir ? "/home/ryan/nixos",
}: let
  # nix, nixos-rebuild and sudo are the system's own (sudo is setuid, so it cannot come from the store).
  path = lib.makeBinPath [nix-output-monitor dix coreutils];
  script = writeTextFile {
    name = "rebuild";
    executable = true;
    destination = "/bin/rebuild";
    text =
      "#!${python3}/bin/python3 -I\n"
      + lib.replaceStrings ["@repoDir@" "@path@"] [repoDir path] (builtins.readFile ./rebuild.py);
    checkPhase = ''
      ${python3}/bin/python3 -m py_compile $target
    '';
  };
in
  script.overrideAttrs (old: {
    passthru =
      (old.passthru or {})
      // {
        tests = runCommand "rebuild-tests" {nativeBuildInputs = [python3];} ''
          export HOME=$TMPDIR
          REBUILD_BIN=${script}/bin/rebuild FIXTURES=${./tests/fixtures} \
            python3 ${./tests/test_rebuild.py} -v
          touch $out
        '';
      };
  })
