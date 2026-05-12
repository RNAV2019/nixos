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
            --color='bg:-1,bg+:-1,gutter:-1,preview-bg:-1,hl:red,fg+:white,pointer:red,prompt:red,info:gray,border:gray,header:gray'
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
in {
  home.packages = [
    bg-switch
    fuzzel-bg-switch
    hyprlock-music
    quasar
    project-picker
  ];
}
