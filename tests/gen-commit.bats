#!/usr/bin/env bats

setup() {
  test_root=$(mktemp -d)
  export HOME="$test_root/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_SYSTEM=/dev/null
  export OPENROUTER_API_KEY=test-key
  export TERM=xterm-256color

  mkdir -p "$HOME" "$test_root/bin" "$test_root/requests"
  install_test_script "$FAKE_GUM_SOURCE" "$test_root/bin/gum"
  install_test_script "$FAKE_API_SOURCE" "$test_root/bin/fake-api"
  install_test_script "$FAKE_EDITOR_SOURCE" "$test_root/bin/fake-editor"
  chmod +x "$test_root/bin/gum" "$test_root/bin/fake-api" "$test_root/bin/fake-editor"

  export PATH="$test_root/bin:$PATH"
  export GEN_COMMIT_API_CLIENT="$test_root/bin/fake-api"
  export GUM_CHOOSE_QUEUE="$test_root/choices"
  export GUM_WRITE_QUEUE="$test_root/writes"
  export API_RESPONSE_QUEUE="$test_root/responses"
  export API_CALLS_FILE="$test_root/api-calls"
  export API_REQUEST_DIR="$test_root/requests"
  export EDITOR_CALLS_FILE="$test_root/editor-calls"
  : > "$GUM_CHOOSE_QUEUE"
  : > "$GUM_WRITE_QUEUE"
  : > "$API_RESPONSE_QUEUE"
  : > "$API_CALLS_FILE"
  : > "$EDITOR_CALLS_FILE"

  repo="$test_root/repo"
  git init --quiet "$repo"
  cd "$repo"
  git config user.name "Gen Commit Test"
  git config user.email "gen-commit@example.test"
  git config commit.gpgSign false
  git config core.editor "$test_root/bin/fake-editor"
  printf 'base\n' > tracked.txt
  git add tracked.txt
  git commit --quiet -m "chore: initial fixture"

  unset GUM_BEFORE_COMMIT_HOOK EDITOR_FAIL EDITOR_MESSAGE
}

install_test_script() {
  {
    printf '#!%s\n' "$BASH"
    tail -n +2 "$1"
  } > "$2"
}

teardown() {
  rm -rf "$test_root"
}

candidate() {
  jq -cn --arg subject "$1" --arg body "${2:-}" --arg reasoning "${3:-Selected for the test.}" \
    '{subject:$subject,body:$body,reasoning:$reasoning}'
}

queue_choices() {
  printf '%s\n' "$@" > "$GUM_CHOOSE_QUEUE"
}

queue_writes() {
  printf '%s\n' "$@" > "$GUM_WRITE_QUEUE"
}

queue_responses() {
  printf '%s\n' "$@" > "$API_RESPONSE_QUEUE"
}

run_gen_commit() {
  run script --quiet --return --command "bash '$GEN_COMMIT_SOURCE'" /dev/null
}

api_call_count() {
  if [[ -s "$API_CALLS_FILE" ]]; then
    cat "$API_CALLS_FILE"
  else
    printf '0'
  fi
}

@test "stages all changes and commits the exact previewed message" {
  printf 'changed\n' > tracked.txt
  printf 'new\n' > new.txt
  queue_choices "Stage all and continue" "Commit"
  queue_responses "$(candidate "feat(files): add staged fixture" "Explain why the fixture is needed.")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(git log -1 --format=%s)" = "feat(files): add staged fixture" ]
  [ "$(git log -1 --format=%b)" = "Explain why the fixture is needed." ]
  [ -z "$(git status --porcelain)" ]
  [[ "$output" == *$'\e[?1049h'* ]]
  [[ "$output" == *$'\e[?1049l'* ]]
  [[ "$output" == *"feat(files): add staged fixture"* ]]
  [[ "$output" == *"Explain why the fixture is needed."* ]]
  [[ "$output" == *"Committed successfully"* ]]
}

@test "creates the first commit in an unborn repository" {
  rm -rf "$repo"
  git init --quiet "$repo"
  cd "$repo"
  git config user.name "Gen Commit Test"
  git config user.email "gen-commit@example.test"
  git config commit.gpgSign false
  printf 'first file\n' > first.txt
  queue_choices "Stage all and continue" "Commit"
  queue_responses "$(candidate "feat: create initial project")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [ "$(git log -1 --format=%s)" = "feat: create initial project" ]
  [ "$(git show HEAD:first.txt)" = "first file" ]
}

@test "cancelling before staging leaves the index untouched and skips the API" {
  printf 'changed\n' > tracked.txt
  queue_choices "Cancel"

  run_gen_commit

  [ "$status" -eq 0 ]
  git diff --cached --quiet
  [ "$(api_call_count)" -eq 0 ]
  [[ "$output" == *"Cancelled"* ]]
}

@test "cancelling after stage all keeps the explicitly staged changes" {
  printf 'changed\n' > tracked.txt
  printf 'new\n' > new.txt
  queue_choices "Stage all and continue" "Cancel"
  queue_responses "$(candidate "feat(files): preview staged changes")"

  run_gen_commit

  [ "$status" -eq 0 ]
  ! git diff --cached --quiet
  [ "$(api_call_count)" -eq 1 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [[ "$output" == *"Cancelled; changes remain staged"* ]]
}

@test "mixed worktrees generate and commit from staged changes only" {
  printf 'staged version\n' > tracked.txt
  git add tracked.txt
  printf 'unstaged version\n' > tracked.txt
  printf 'untracked\n' > untracked.txt
  queue_choices "Commit"
  queue_responses "$(candidate "fix(files): commit staged version")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(git show HEAD:tracked.txt)" = "staged version" ]
  [ "$(git status --short tracked.txt)" = " M tracked.txt" ]
  [ "$(git status --short untracked.txt)" = "?? untracked.txt" ]
  grep -q "staged version" "$API_REQUEST_DIR/request-1.json"
  ! grep -q "unstaged version" "$API_REQUEST_DIR/request-1.json"
  ! grep -q "untracked.txt" "$API_REQUEST_DIR/request-1.json"
  [[ "$output" == *"will be excluded"* ]]
}

@test "manual editing returns to preview and requires an explicit commit" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  export EDITOR_MESSAGE='fix(editor): use the reviewed message\n\nExplain the manual correction.'
  queue_choices "Edit manually" "Commit"
  queue_responses "$(candidate "chore: initial generated message")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(git log -1 --format=%s)" = "fix(editor): use the reviewed message" ]
  [ "$(git log -1 --format=%b)" = "Explain the manual correction." ]
  [ "$(api_call_count)" -eq 1 ]
  [ "$(wc -l < "$EDITOR_CALLS_FILE")" -eq 1 ]
  [ ! -s "$GUM_CHOOSE_QUEUE" ]
  after_first_screen=${output#*$'\e[?1049h'}
  [[ "$after_first_screen" == *$'\e[?1049h'* ]]
  [[ "$output" == *"fix(editor): use the reviewed message"* ]]
  [[ "$output" == *"Explain the manual correction."* ]]
}

@test "empty AI feedback returns to preview without another request" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  queue_choices "Edit with AI" "Cancel"
  queue_writes "__EMPTY__"
  queue_responses "$(candidate "chore: keep generated message")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(api_call_count)" -eq 1 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [[ "$output" == *"No feedback entered"* ]]
}

@test "cancelling AI feedback returns to the action menu" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  queue_choices "Edit with AI" "Cancel"
  queue_writes "__CANCEL__"
  queue_responses "$(candidate "chore: keep candidate after feedback cancel")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(api_call_count)" -eq 1 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [[ "$output" == *"AI edit cancelled"* ]]
}

@test "AI refinement sends the prior candidate exactly once" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  queue_choices "Edit with AI" "Commit"
  queue_writes "Use fix with the config scope"
  queue_responses \
    "$(candidate "chore: update configuration")" \
    "$(candidate "fix(config): correct configuration")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(api_call_count)" -eq 2 ]
  [ "$(git log -1 --format=%s)" = "fix(config): correct configuration" ]
  [ "$(jq -r '.messages[2].content | fromjson | .subject' "$API_REQUEST_DIR/request-2.json")" = "chore: update configuration" ]
  [ "$(jq -r '.messages[3].content' "$API_REQUEST_DIR/request-2.json")" = "Use fix with the config scope" ]
}

@test "an invalid initial response is repaired once before preview" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  queue_choices "Commit"
  queue_responses \
    "$(candidate "this is not conventional")" \
    "$(candidate "fix(config): repair invalid response")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(api_call_count)" -eq 2 ]
  [ "$(git log -1 --format=%s)" = "fix(config): repair invalid response" ]
  [ "$(jq -r '.messages[3].content' "$API_REQUEST_DIR/request-2.json")" = "Use the format type(scope): description with an allowed Conventional Commit type. Return the complete corrected JSON object." ]
}

@test "a failed AI refinement keeps the previous candidate" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  queue_choices "Edit with AI" "Commit"
  queue_writes "Try another type"
  queue_responses \
    "$(candidate "chore: keep candidate after API failure")" \
    "__HTTP_500__"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(api_call_count)" -eq 2 ]
  [ "$(git log -1 --format=%s)" = "chore: keep candidate after API failure" ]
  [[ "$output" == *"Keeping the previous message"* ]]
}

@test "a failed editor keeps the candidate and does not commit" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  export EDITOR_FAIL=true
  queue_choices "Edit manually" "Cancel"
  queue_responses "$(candidate "chore: keep candidate after editor failure")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [[ "$output" == *"Manual edit cancelled"* ]]
}

@test "a changed staged tree is rejected before commit" {
  printf 'first staged version\n' > tracked.txt
  git add tracked.txt
  hook="$test_root/change-index.sh"
  cat > "$hook" <<'EOF'
printf 'second staged version\n' > tracked.txt
git add tracked.txt
EOF
  export GUM_BEFORE_COMMIT_HOOK="$hook"
  queue_choices "Commit"
  queue_responses "$(candidate "fix(files): preserve generated snapshot")"

  run_gen_commit

  [ "$status" -eq 1 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [ "$(git show :tracked.txt)" = "second staged version" ]
  [[ "$output" == *"Staged changes changed while editing"* ]]
}

@test "a changed HEAD is rejected before commit" {
  printf 'staged version\n' > tracked.txt
  git add tracked.txt
  hook="$test_root/change-head.sh"
  cat > "$hook" <<'EOF'
git commit --quiet -m "chore: concurrent commit"
EOF
  export GUM_BEFORE_COMMIT_HOOK="$hook"
  queue_choices "Commit"
  queue_responses "$(candidate "fix(files): preserve generated parent")"

  run_gen_commit

  [ "$status" -eq 1 ]
  [ "$(git rev-list --count HEAD)" -eq 2 ]
  [ "$(git log -1 --format=%s)" = "chore: concurrent commit" ]
  [[ "$output" == *"current branch or HEAD changed"* ]]
}

@test "the AI edit limit never opens an editor or creates a commit" {
  printf 'changed\n' > tracked.txt
  git add tracked.txt
  queue_choices \
    "Edit with AI" "Edit with AI" "Edit with AI" \
    "Edit with AI" "Edit with AI" "Edit with AI" "Cancel"
  queue_writes "one" "two" "three" "four" "five"
  queue_responses \
    "$(candidate "chore: initial candidate")" \
    "$(candidate "chore: first candidate")" \
    "$(candidate "chore: second candidate")" \
    "$(candidate "chore: third candidate")" \
    "$(candidate "chore: fourth candidate")" \
    "$(candidate "chore: fifth candidate")"

  run_gen_commit

  [ "$status" -eq 0 ]
  [ "$(api_call_count)" -eq 6 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [ ! -s "$EDITOR_CALLS_FILE" ]
  [[ "$output" == *"AI edit limit reached"* ]]
}

@test "non-interactive use fails before staging or contacting the API" {
  printf 'changed\n' > tracked.txt

  run bash "$GEN_COMMIT_SOURCE"

  [ "$status" -eq 1 ]
  git diff --cached --quiet
  [ "$(api_call_count)" -eq 0 ]
  [[ "$output" == *"requires an interactive terminal"* ]]
}

@test "a missing API key is reported before staging" {
  printf 'changed\n' > tracked.txt
  unset OPENROUTER_API_KEY

  run_gen_commit

  [ "$status" -eq 1 ]
  git diff --cached --quiet
  [ "$(api_call_count)" -eq 0 ]
  [[ "$output" == *"API key not found"* ]]
}

@test "a malformed pre-commit hook fails before generation" {
  printf 'changed\n' > tracked.txt
  hook_path=$(git rev-parse --git-path hooks/pre-commit)
  printf '#!/bin/sh\\nprintf test > hook-output\\n' > "$hook_path"
  chmod +x "$hook_path"

  run_gen_commit

  [ "$status" -eq 1 ]
  [ "$(api_call_count)" -eq 0 ]
  [ ! -e hook-output ]
  [[ "$output" == *"Pre-commit hook uses a missing interpreter"* ]]
  [[ "$output" == *"Fix or remove"* ]]
}
