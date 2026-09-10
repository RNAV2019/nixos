{
  pkgs,
  icalAgenda,
}:
pkgs.runCommand "ical-agenda-tests" {
  nativeBuildInputs = [
    pkgs.bash
    pkgs.bats
    pkgs.coreutils
    pkgs.gawk
    pkgs.gnugrep
  ];
} ''
  ${icalAgenda}/bin/ical-agenda --help | grep -q "tab-separated agenda"

  export PATH=${icalAgenda}/bin:$PATH
  export FIXTURE_DIR=${./fixtures}
  bats --print-output-on-failure ${./ical-agenda.bats}
  touch "$out"
''
