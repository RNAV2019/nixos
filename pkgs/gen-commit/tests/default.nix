{
  runCommand,
  gen-commit,
  bash,
  bats,
  coreutils,
  git,
  gnugrep,
  jq,
  util-linux,
}:
runCommand "gen-commit-tests" {
  nativeBuildInputs = [bash bats coreutils git gnugrep jq util-linux];
} ''
  ${gen-commit}/bin/gen-commit --help | grep -q "Generate and commit"

  key_root=$(mktemp -d)
  HOME="$key_root/home" XDG_CONFIG_HOME="$key_root/config" \
    ${gen-commit}/bin/gen-commit --key test-key >/dev/null
  test "$(stat -c %a "$key_root/config/gen-commit")" = 700
  test "$(stat -c %a "$key_root/config/gen-commit/api-key")" = 600

  export GEN_COMMIT_SOURCE=${../gen-commit.sh}
  export FAKE_GUM_SOURCE=${./fake-gum.sh}
  export FAKE_API_SOURCE=${./fake-api.sh}
  export FAKE_EDITOR_SOURCE=${./fake-editor.sh}
  bats --print-output-on-failure ${./gen-commit.bats}
  touch "$out"
''
