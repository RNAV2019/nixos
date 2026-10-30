# Claude Code hooks that tell the Quickshell island when a session needs the user, and the
# helper that raises that session's terminal. Hooks run on every tool call, so the script is
# plain stdlib Python started without site: about 15 ms.
{
  writeTextFile,
  python3,
  runCommand,
}: let
  script = writeTextFile {
    name = "claude-island";
    executable = true;
    destination = "/bin/claude-island";
    text = "#!${python3}/bin/python3 -IS\n" + builtins.readFile ./claude-island.py;
    checkPhase = ''
      ${python3}/bin/python3 -m py_compile $target
    '';
  };
in
  script.overrideAttrs (old: {
    passthru =
      (old.passthru or {})
      // {
        tests = runCommand "claude-island-tests" {nativeBuildInputs = [python3];} ''
          export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run
          mkdir -p $XDG_RUNTIME_DIR
          CLAUDE_ISLAND_BIN=${script}/bin/claude-island \
            python3 ${./tests/test_claude_island.py} -v
          touch $out
        '';
      };
  })
