{pkgs}: let
  gen-commit-api = pkgs.writeShellApplication {
    name = "gen-commit-api";
    runtimeInputs = [pkgs.coreutils pkgs.curl];
    text = ''
      if [[ $# -ne 1 ]]; then
        printf 'usage: gen-commit-api REQUEST_FILE\n' >&2
        exit 2
      fi

      : "''${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required}"
      body_file="$1"
      header_file=$(mktemp)
      trap 'rm -f "$header_file"' EXIT
      chmod 600 "$header_file"
      printf 'Authorization: Bearer %s\n' "$OPENROUTER_API_KEY" > "$header_file"

      curl --disable \
        --silent --show-error \
        --connect-timeout 10 \
        --max-time 90 \
        --write-out '\n%{http_code}' \
        --request POST "https://openrouter.ai/api/v1/chat/completions" \
        --header @"$header_file" \
        --header "Content-Type: application/json" \
        --header "X-Title: gen-commit" \
        --data @"$body_file"
    '';
  };
in
  pkgs.writeShellApplication {
    name = "gen-commit";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.gum
      pkgs.jq
    ];
    text =
      ''
        GEN_COMMIT_API_CLIENT="''${GEN_COMMIT_API_CLIENT:-${gen-commit-api}/bin/gen-commit-api}"
        export GEN_COMMIT_API_CLIENT
      ''
      + builtins.readFile ./gen-commit.sh;
  }
