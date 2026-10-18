{
  runCommand,
  ical-agenda,
  bash,
  bats,
  coreutils,
  gawk,
  gnugrep,
}:
runCommand "ical-agenda-tests" {
  nativeBuildInputs = [bash bats coreutils gawk gnugrep];
} ''
  ${ical-agenda}/bin/ical-agenda --help | grep -q "tab-separated agenda"

  export PATH=${ical-agenda}/bin:$PATH
  export FIXTURE_DIR=${./fixtures}
  bats --print-output-on-failure ${./ical-agenda.bats}
  touch "$out"
''
