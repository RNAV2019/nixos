{pkgs}: let
  gen-commit-api = pkgs.writeShellScript "gen-commit-api" ''
    set -euo pipefail
    api_key="$1"
    body_file="$2"
    curl -s -w "\n%{http_code}" \
      -X POST "https://openrouter.ai/api/v1/chat/completions" \
      -H "Authorization: Bearer $api_key" \
      -H "Content-Type: application/json" \
      -H "X-Title: gen-commit" \
      -d @"$body_file"
  '';
in
  pkgs.writeShellApplication {
    name = "gen-commit";
    runtimeInputs = [pkgs.git pkgs.curl pkgs.jq pkgs.gum];
    excludeShellChecks = ["SC2016"];
    text = ''
            # Rose Pine Moon palette
            RP_OVERLAY="#393552"
            RP_MUTED="#6e6a86"
            RP_SUBTLE="#908caa"
            RP_TEXT="#e0def4"
            RP_LOVE="#eb6f92"
            RP_GOLD="#f6c177"
            RP_FOAM="#9ccfd8"
            RP_PINE="#3e8fb0"
            RP_IRIS="#c4a7e7"

            MODEL="google/gemini-2.5-flash-lite"
            MAX_ITER=5

            while [[ $# -gt 0 ]]; do
              case "$1" in
                --model)
                  if [[ $# -lt 2 ]]; then
                    gum style --foreground "$RP_LOVE" "--model requires a value"
                    exit 1
                  fi
                  MODEL="$2"; shift 2 ;;
                --key)
                  if [[ $# -lt 2 ]]; then
                    gum style --foreground "$RP_LOVE" "--key requires a value"
                    exit 1
                  fi
                  key_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/gen-commit"
                  mkdir -p "$key_dir"
                  printf '%s\n' "$2" > "$key_dir/api-key"
                  gum style --foreground "$RP_FOAM" "  API key saved to $key_dir/api-key"
                  exit 0 ;;
                *)
                  gum style --foreground "$RP_LOVE" "Unknown flag: $1"
                  exit 1 ;;
              esac
            done

            # ── git validation ─────────────────────────────────────────────────────────
            if ! git rev-parse --git-dir > /dev/null 2>&1; then
              gum style --foreground "$RP_LOVE" "  Not a git repository"
              exit 1
            fi

            staged=$(git diff --staged --name-only)
            unstaged=$(git diff --name-only)
            untracked=$(git ls-files --others --exclude-standard)

            if [[ -z "$staged" && -z "$unstaged" && -z "$untracked" ]]; then
              gum style --foreground "$RP_MUTED" "  Nothing to commit — working tree clean"
              exit 0
            fi

            # ── diff collection ────────────────────────────────────────────────────────
            diff_source="staged"
            if [[ -z "$staged" ]]; then
              gum style --foreground "$RP_GOLD" "  No staged changes"
              if gum confirm "Stage all changes?" \
                   --affirmative="Stage all" \
                   --negative="Use HEAD diff"; then
                git add -A
                diff_content=$(git diff --staged)
                diff_source="staged (just added)"
              else
                diff_content=$(git diff HEAD)
                diff_source="HEAD"
              fi
            else
              diff_content=$(git diff --staged)
            fi

            status_summary=$(git status --short)
            file_count=$(printf '%s' "$status_summary" | awk 'END{print NR}')

            # Truncate diffs that would blow the model context
            MAX_DIFF=12000
            truncation_note=""
            if [[ ''${#diff_content} -gt $MAX_DIFF ]]; then
              truncation_note="
      (diff truncated — first 50 lines per file shown)"
              diff_content=$(printf '%s' "$diff_content" | awk "
                /^diff --git/ { file_lines=0 }
                file_lines < 50 { print; file_lines++ }
                file_lines == 50 { print \"[... truncated ...]\"; file_lines++ }
              ")
            fi

            # ── api key ────────────────────────────────────────────────────────────────
            api_key=""
            if [[ -n "''${OPENROUTER_API_KEY:-}" ]]; then
              api_key="$OPENROUTER_API_KEY"
            else
              key_file="''${XDG_CONFIG_HOME:-$HOME/.config}/gen-commit/api-key"
              if [[ -f "$key_file" ]]; then
                api_key=$(head -n1 "$key_file" | tr -d '[:space:]')
              fi
            fi

            if [[ -z "$api_key" ]]; then
              gum style \
                --foreground "$RP_LOVE" \
                --border rounded \
                --border-foreground "$RP_LOVE" \
                --padding "0 1" \
                "  API key not found

        Set OPENROUTER_API_KEY env var, or write your key to:
        ''${XDG_CONFIG_HOME:-$HOME/.config}/gen-commit/api-key"
              exit 1
            fi

            # ── temp workspace ─────────────────────────────────────────────────────────
            tmpdir=$(mktemp -d /tmp/gen-commit-XXXXXX)
            body_file="$tmpdir/request.json"
            msg_file="$tmpdir/message.txt"
            log_file="$tmpdir/debug.log"
            printf 'gen-commit log: %s\n' "$tmpdir" >&2

            # ── system prompt ──────────────────────────────────────────────────────────
            SYSTEM_PROMPT=$(cat <<SYSPROMPT
      You are an expert git commit message writer following the Conventional Commits specification.
      Return ONLY valid JSON with exactly these three keys:
      - "subject": commit subject line. Format: type(scope): description. type must be one of: feat, fix, refactor, docs, style, test, chore, perf, ci, build. scope is optional but recommended when obvious. description: imperative mood, lowercase, no trailing period. Maximum 72 characters total.
      - "body": optional multi-line body explaining WHY, not what. Empty string if not needed. Wrap lines at 72 chars. Do not repeat the subject.
      - "reasoning": one sentence explaining your choice of type and scope.
      Analyze the diff carefully. Prefer precise types over generic ones.
      SYSPROMPT
      )

            initial_prompt="Generate a conventional commit message for these changes.

      Git status ($file_count file(s) changed):
      $status_summary

      Diff source: $diff_source$truncation_note

      Diff:
      $diff_content"

            prompt_file="$tmpdir/prompt.txt"
            printf '%s' "$initial_prompt" > "$prompt_file"
            messages=$(jq -n \
              --arg sys "$SYSTEM_PROMPT" \
              --rawfile usr "$prompt_file" \
              '[{role:"system",content:$sys},{role:"user",content:$usr}]')

            iteration=0
            subject=""
            body_text=""
            reasoning=""

            # ── main loop ──────────────────────────────────────────────────────────────
            while true; do
              printf '%s' "$messages" | jq \
                --arg model "$MODEL" \
                '{model:$model,messages:.,response_format:{type:"json_object"},max_tokens:2048,temperature:0.3}' \
                > "$body_file"

              response=$(gum spin \
                --spinner dot \
                --title "  Generating commit message..." \
                --spinner.foreground="$RP_IRIS" \
                -- ${gen-commit-api} "$api_key" "$body_file")

              http_code=$(printf '%s' "$response" | tail -1)
              api_body=$(printf '%s' "$response" | head -n -1)

              {
                printf '%s\n' "=== iteration $iteration ==="
                printf '%s\n' "http_code: $http_code"
                printf '%s\n' "api_body:" "$api_body"
              } >> "$log_file"

              if [[ "$http_code" != "200" ]]; then
                err_msg=$(printf '%s' "$api_body" | jq -r '.error.message // "Unknown error"' 2>/dev/null \
                  || printf '%s' "$api_body")
                gum style --foreground "$RP_LOVE" "  API error $http_code: $err_msg"
                exit 1
              fi

              finish_reason=$(printf '%s' "$api_body" | jq -r '.choices[0].finish_reason // ""')
              content=$(printf '%s' "$api_body" | jq -r '.choices[0].message.content // ""')
              if [[ "$finish_reason" == "length" || -z "$content" ]]; then
                gum style --foreground "$RP_GOLD" "  Model hit token limit (finish_reason: $finish_reason) — increase max_tokens or use a smaller diff"
                printf '%s\n' "finish_reason: $finish_reason  content was empty" >> "$log_file"
                exit 1
              fi
              subject=$(printf '%s' "$content" | jq -r '.subject // ""' 2>/dev/null || true)
              body_text=$(printf '%s' "$content" | jq -r '.body // ""' 2>/dev/null || true)
              reasoning=$(printf '%s' "$content" | jq -r '.reasoning // ""' 2>/dev/null || true)

              {
                printf '%s\n' "content:" "$content"
                printf '%s\n' "subject (''${#subject} chars):" "$subject"
                printf '%s\n' "body_text:" "$body_text"
                printf '%s\n' "reasoning:" "$reasoning"
              } >> "$log_file"

              # Validate subject
              if [[ -z "$subject" || ''${#subject} -gt 72 ]]; then
                if [[ $iteration -ge 1 ]]; then
                  gum style --foreground "$RP_LOVE" \
                    "  AI returned an invalid subject line. Run again or use --model to try a different model."
                  printf 'log: %s\n' "$log_file" >&2
                  exit 1
                fi
                iteration=$((iteration + 1))
                fix_msg=$(jq -n \
                  --arg c "The subject is ''${#subject} characters long — it must be 72 characters or fewer. Shorten it significantly. Do not list every changed file; pick the primary theme of the change instead." \
                  '{role:"user",content:$c}')
                messages=$(printf '%s' "$messages" | jq --argjson f "$fix_msg" '. + [$f]')
                continue
              fi

              # ── display panel ────────────────────────────────────────────────────────
              S_DISP=$(gum style --foreground "$RP_TEXT" --bold "$subject")

              # Body: first sentence only
              body_short=""
              if [[ -n "$body_text" ]]; then
                body_short="''${body_text%%.*}."
                [[ ''${#body_short} -gt 100 ]] && body_short="''${body_short:0:97}..."
                B_DISP=$(gum style --foreground "$RP_SUBTLE" "$body_short")
              fi

              # Files: compact single line
              files_inline=$(printf '%s' "$status_summary" | head -3 | awk '{print $2}' | paste -sd ', ')
              [[ $file_count -gt 3 ]] && files_inline="$files_inline +$((file_count - 3)) more"
              F_DISP=$(gum style --foreground "$RP_PINE" "$file_count files  $files_inline")

              # Reasoning: one short line
              reasoning_short="''${reasoning:0:72}"
              [[ ''${#reasoning} -gt 72 ]] && reasoning_short="''${reasoning_short}..."
              R_DISP=$(gum style --foreground "$RP_MUTED" --italic "$reasoning_short")

              if [[ -n "$body_short" ]]; then
                PANEL=$(gum join --vertical \
                  "$S_DISP" "$B_DISP" "" "$F_DISP" "$R_DISP")
              else
                PANEL=$(gum join --vertical \
                  "$S_DISP" "" "$F_DISP" "$R_DISP")
              fi

              gum style \
                --border rounded \
                --border-foreground "$RP_OVERLAY" \
                --padding "0 2" \
                --margin "1 0" \
                --width 76 \
                "$PANEL"

              # ── action menu ──────────────────────────────────────────────────────────
              action=$(gum choose \
                --header=" What would you like to do?" \
                --header.foreground="$RP_MUTED" \
                --cursor.foreground="$RP_FOAM" \
                --selected.foreground="$RP_FOAM" \
                " Confirm" \
                " Edit with AI" \
                " Edit manually" \
                " Cancel" || true)

              case "$action" in
                " Confirm")
                  break ;;

                " Edit with AI")
                  if [[ $iteration -ge $MAX_ITER ]]; then
                    gum style --foreground "$RP_GOLD" \
                      "  Max AI iterations reached — opening editor"
                    printf '%s\n' "$subject" > "$msg_file"
                    [[ -n "$body_text" ]] && printf '\n%s\n' "$body_text" >> "$msg_file"
                    git commit -e -F "$msg_file"
                    exit 0
                  fi

                  feedback=$(gum write \
                    --width 72 \
                    --height 5 \
                    --placeholder "Describe what to change (e.g. 'use fix type, add auth as scope')" \
                    --header " Your feedback:" \
                    --header.foreground="$RP_IRIS" \
                    --char-limit 500 || true)

                  [[ -z "$feedback" ]] && feedback="Please try a different approach."

                  asst_json=$(jq -n \
                    --arg s "$subject" --arg b "$body_text" --arg r "$reasoning" \
                    '{subject:$s,body:$b,reasoning:$r} | tojson')
                  messages=$(printf '%s' "$messages" | jq \
                    --arg a "$asst_json" \
                    --arg f "$feedback" \
                    '. + [{role:"assistant",content:$a},{role:"user",content:$f}]')

                  iteration=$((iteration + 1))
                  ;;

                " Edit manually")
                  printf '%s\n' "$subject" > "$msg_file"
                  [[ -n "$body_text" ]] && printf '\n%s\n' "$body_text" >> "$msg_file"
                  git commit -e -F "$msg_file"
                  exit 0 ;;

                " Cancel"|"")
                  gum style --foreground "$RP_MUTED" "  Cancelled"
                  exit 0 ;;
              esac
            done

            # ── commit ─────────────────────────────────────────────────────────────────
            if [[ -n "$body_text" ]]; then
              git commit -m "$subject" -m "$body_text"
            else
              git commit -m "$subject"
            fi

            gum style \
              --foreground "$RP_FOAM" \
              --bold \
              "   Committed successfully"
    '';
  }
