{
  config,
  pkgs,
  ...
}: let
  bg-preview = pkgs.writeShellScript "bg-preview" ''
    set -eu
    file="$1"
    cache_dir="$HOME/.cache/bg-switch"
    mkdir -p "$cache_dir"
    mtime=$(stat -c %Y "$file")
    key=$(printf '%s_%s_%sx%s' "$file" "$mtime" "$FZF_PREVIEW_COLUMNS" "$FZF_PREVIEW_LINES" | sha256sum | cut -d' ' -f1)
    cache_file="$cache_dir/$key"
    if [ ! -s "$cache_file" ]; then
      ${pkgs.chafa}/bin/chafa --size="$FZF_PREVIEW_COLUMNS"x"$FZF_PREVIEW_LINES" "$file" > "$cache_file"
    fi
    cat "$cache_file"
  '';

  bg-apply = pkgs.writeShellScript "bg-apply" ''
    set -eu
    selected="$1"
    CURRENT_LINK="$HOME/.local/share/wallpaper/current"
    ${pkgs.awww}/bin/awww img "$selected" --transition-type grow --transition-pos center --transition-duration 0.9 --transition-fps 120
    ln -sf "$selected" "$CURRENT_LINK"
    ${pkgs.libnotify}/bin/notify-send "Background" "Changed to $(basename "$selected")"
  '';

  bg-switch = pkgs.writeShellApplication {
    name = "bg-switch";
    runtimeInputs = [pkgs.fzf pkgs.chafa pkgs.libnotify pkgs.awww];
    excludeShellChecks = ["SC2016"];
    text = ''
      WALLPAPER_DIR="$HOME/Pictures/backgrounds"

      # Warm the preview cache in the background so first navigation is fast.
      (
        find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) |
          while IFS= read -r f; do
            FZF_PREVIEW_COLUMNS=80 FZF_PREVIEW_LINES=24 ${bg-preview} "$f" >/dev/null 2>&1 || true
          done
      ) &

      selected=$(
        find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) |
          sort |
          fzf \
            --preview '${bg-preview} {}' \
            --preview-window='right:60%:border-left' \
            --prompt='  wallpaper > ' \
            --header='↑↓ navigate · enter select · esc quit' \
            --border=rounded \
            --height=100% \
            --color='bg:-1,bg+:-1,gutter:-1,preview-bg:-1,hl:#eb6f92,fg+:#e0def4,pointer:#eb6f92,prompt:#eb6f92,info:#908caa,border:#403d52,header:#908caa'
      )

      [ -z "$selected" ] && exit 0
      ${bg-apply} "$selected"
    '';
  };

  fuzzel-bg-switch = pkgs.writeShellApplication {
    name = "fuzzel-bg-switch";
    runtimeInputs = [pkgs.fuzzel pkgs.libnotify pkgs.awww];
    text = ''
      WALLPAPER_DIR="$HOME/Pictures/backgrounds"

      mapfile -t files < <(
        find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | sort
      )
      [ ''${#files[@]} -eq 0 ] && exit 0

      menu=""
      for f in "''${files[@]}"; do
        name="$(basename "$f")"
        menu+="$name"$'\t'"$f"$'\n'
      done

      choice=$(printf '%s' "$menu" | cut -f1 | fuzzel --dmenu --prompt='  wallpaper > ')
      [ -z "$choice" ] && exit 0

      selected=$(printf '%s' "$menu" | awk -F'\t' -v k="$choice" '$1==k {print $2; exit}')
      [ -z "$selected" ] && exit 0

      ${bg-apply} "$selected"
    '';
  };

  hyprlock-music = pkgs.writeShellApplication {
    name = "hyprlock-music";
    runtimeInputs = [pkgs.playerctl];
    text = ''
      status=$(playerctl status 2>/dev/null || true)
      if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
        playerctl metadata --format "{{title}} - {{artist}}" 2>/dev/null || true
      fi
    '';
  };

  quasar = pkgs.buildGoModule {
    pname = "quasar";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "quasar";
      rev = "9ff1c7a5b72ed2876d9ceffe1a6fde6ab0303b30";
      hash = "sha256-wlFt3OpZfPsssDW/Di6uirhusEQjUB/WoQAnvTFHXtU=";
    };
    vendorHash = "sha256-U4HAzSi3BT4yPGceEPnvSyQkl1UoeP3mmSHZsgnEffw=";
  };

  project-picker = pkgs.rustPlatform.buildRustPackage {
    pname = "project-picker";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "project-picker";
      rev = "428b15e90d2a2ce388e64c8d2a547bb03f013fa0";
      hash = "sha256-Ia+e7d4tYqoThYq3ngvUXn5UUFZJ4FJRdFAP5SXfhRM=";
    };
    cargoHash = "sha256-eGF9ASlbZaeg+2m0vEBZt0+1fGjWleUXkrTy+UbgW4A=";
  };

  # Isolated curl helper so gum spin can call it across a subshell boundary.
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

  gen-commit = pkgs.writeShellApplication {
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

            MODEL="deepseek/deepseek-v4-flash"
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

            messages=$(jq -n \
              --arg sys "$SYSTEM_PROMPT" \
              --arg usr "$initial_prompt" \
              '[{role:"system",content:$sys},{role:"user",content:$usr}]')

            iteration=0
            subject=""
            body_text=""
            reasoning=""

            # ── main loop ──────────────────────────────────────────────────────────────
            while true; do
              jq -n \
                --argjson msgs "$messages" \
                --arg model "$MODEL" \
                '{model:$model,messages:$msgs,response_format:{type:"json_object"},max_tokens:2048,temperature:0.3}' \
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
  };
in {
  home.packages = [
    bg-switch
    fuzzel-bg-switch
    hyprlock-music
    quasar
    project-picker
    gen-commit
  ];
}
