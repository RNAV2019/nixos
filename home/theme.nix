{
  config,
  lib,
  pkgs,
  ...
}: let
  # The desktop has two themes, switched at runtime rather than at build time. Every
  # program's colours live in one store directory per theme, generated below from
  # themes/palettes.nix. ~/.local/state/theme/current links to the active one, and each
  # program reads its colours through that link, so switching is a matter of moving the link
  # and telling whatever is already running. `theme-switch <id>` does both; Quickshell's
  # theme picker (ALT+T) calls it.
  palettes = import ./themes/palettes.nix;
  ids = lib.attrNames palettes;
  rp = palettes.rose-pine;

  home = config.home.homeDirectory;
  stateDir = "${home}/.local/state/theme";
  current = "${stateDir}/current";
  link = config.lib.file.mkOutOfStoreSymlink;

  toml = pkgs.formats.toml {};
  yaml = pkgs.formats.yaml {};

  bare = lib.removePrefix "#";
  rgb = hex: let
    h = bare hex;
  in
    map (i: lib.fromHexString (builtins.substring i 2 h)) [0 2 4];
  rgbWith = sep: hex: lib.concatMapStringsSep sep toString (rgb hex);

  # Several fragments are upstream Rose Pine files written in its own hex values. The dark
  # version of each is the same file with every role's value swapped for the dark one.
  roles = ["base" "surface" "overlay" "muted" "subtle" "text" "love" "gold" "rose" "pine" "foam" "iris" "highlightLow" "highlightMed" "highlightHigh"];
  recolour = p: text: let
    from = map (r: rp.${r}) roles;
    to = map (r: p.${r}) roles;
  in
    builtins.replaceStrings (from ++ map lib.toUpper from) (to ++ to) text;

  yaziRosePine = "${pkgs.fetchFromGitHub {
    owner = "rose-pine";
    repo = "yazi";
    rev = "c89d745573d4fcfe0550fe6646f9f9ab1c0e51db";
    hash = "sha256-9e3dXViWl1rK9BPrGAFfs9ZL/tsG6Njz6ksuU6AIrFY=";
  }}/flavors/rose-pine.yazi";

  btopRosePine = ''
    theme[main_bg]="#191724"
    theme[main_fg]="#e0def4"
    theme[title]="#e0def4"
    theme[hi_fg]="#eb6f92"
    theme[selected_bg]="#26233a"
    theme[selected_fg]="#eb6f92"
    theme[inactive_fg]="#6e6a86"
    theme[graph_text]="#908caa"
    theme[meter_bg]="#26233a"
    theme[proc_misc]="#c4a7e7"
    theme[cpu_box]="#403d52"
    theme[mem_box]="#403d52"
    theme[net_box]="#403d52"
    theme[proc_box]="#403d52"
    theme[div_line]="#26233a"
    theme[temp_start]="#9ccfd8"
    theme[temp_mid]="#f6c177"
    theme[temp_end]="#eb6f92"
    theme[cpu_start]="#9ccfd8"
    theme[cpu_mid]="#c4a7e7"
    theme[cpu_end]="#eb6f92"
    theme[free_start]="#31748f"
    theme[free_mid]="#9ccfd8"
    theme[free_end]="#e0def4"
    theme[cached_start]="#403d52"
    theme[cached_mid]="#6e6a86"
    theme[cached_end]="#908caa"
    theme[available_start]="#9ccfd8"
    theme[available_mid]="#c4a7e7"
    theme[available_end]="#e0def4"
    theme[used_start]="#f6c177"
    theme[used_mid]="#ebbcba"
    theme[used_end]="#eb6f92"
    theme[download_start]="#31748f"
    theme[download_mid]="#9ccfd8"
    theme[download_end]="#e0def4"
    theme[upload_start]="#f6c177"
    theme[upload_mid]="#ebbcba"
    theme[upload_end]="#eb6f92"
    theme[process_start]="#31748f"
    theme[process_mid]="#c4a7e7"
    theme[process_end]="#eb6f92"
  '';

  # Everything the switch script needs to know about a theme that is not a colour.
  # `colorScheme` is the freedesktop appearance value the settings portal
  # broadcasts: Helium and every libadwaita app follow it live.
  extras = {
    rose-pine = {
      ghostty = "theme = Rose Pine\n";
      helix = ./themes/rose_pine_transparent.toml;
      bat = "Rose-Pine-Moon";
      herdr = "rose-pine";
      gtkTheme = "rose-pine";
      iconTheme = "rose-pine";
      colorScheme = "prefer-dark";
      kvantum = "rose-pine-love";
      yazi = yaziRosePine;
    };

    dark = let
      p = palettes.dark;
    in {
      ghostty =
        ''
          background = ${p.base}
          foreground = ${p.text}
          cursor-color = ${p.text}
          cursor-text = ${p.base}
          selection-background = ${p.highlightMed}
          selection-foreground = ${p.text}
        ''
        + lib.concatStrings (lib.imap0 (i: c: "palette = ${toString i}=${c}\n") p.ansi);
      helix = ./themes/ascii_world.toml;
      # bat's built-in ANSI theme, which draws in the terminal's own sixteen colours.
      bat = "ansi";
      # herdr's built-in `terminal` theme does the same.
      herdr = "terminal";
      gtkTheme = "Adwaita-dark";
      iconTheme = "Adwaita";
      colorScheme = "prefer-dark";
      kvantum = "KvGnomeDark";
      yazi =
        pkgs.linkFarm "ascii-world.yazi" (lib.genAttrs ["flavor.toml" "tmtheme.xml"] (file:
            pkgs.writeText "ascii-world-${file}" (recolour p (builtins.readFile "${yaziRosePine}/${file}"))));
    };
  };

  tmuxFragment = id: p:
    if id == "rose-pine"
    then ''
      set -g @rose_pine_variant 'main'
      set -g @rose_pine_host 'on'
      set -g @rose_pine_date_time '%Y-%m-%d %H:%M'
      set -g @rose_pine_directory 'on'
      run-shell ${pkgs.tmuxPlugins.rose-pine}/share/tmux-plugins/rose-pine/rose-pine.tmux

      # rose-pine sets the message styles without a `fill`, and tmux clears the
      # status line behind the command prompt only as far as the fill reaches —
      # without it the window list and status-right stay visible under `:`.
      set -ag message-style ",fill=${p.base}"
      set -ag message-command-style ",fill=${p.gold}"
    ''
    # Every option the rose-pine plugin sets is set here too, so switching away from it
    # leaves nothing of it behind.
    else ''
      set -g status on
      set -g status-justify left
      set -g status-style "fg=${p.subtle},bg=${p.base}"
      set -g status-left "#[fg=${p.base},bg=${p.text},bold] #S #[default] "
      set -g status-left-length 40
      set -g status-right "#[fg=${p.muted}]#{b:pane_current_path}  #[fg=${p.subtle}]%Y-%m-%d %H:%M #[fg=${p.base},bg=${p.foam}] #h "
      set -g status-right-length 120
      set -g window-status-separator ""
      set -g window-status-style "fg=${p.muted},bg=${p.base}"
      set -g window-status-current-style "fg=${p.text},bg=${p.base},bold"
      set -g window-status-activity-style "fg=${p.gold},bg=${p.base}"
      set -g window-status-format " #I #W "
      set -g window-status-current-format " #I #W "
      set -g pane-border-style "fg=${p.highlightMed}"
      set -g pane-active-border-style "fg=${p.subtle}"
      set -g message-style "fg=${p.text},bg=${p.surface},fill=${p.surface}"
      set -g message-command-style "fg=${p.base},bg=${p.gold},fill=${p.gold}"
      set -g mode-style "fg=${p.base},bg=${p.foam}"
      set -g display-panes-colour "${p.muted}"
      set -g display-panes-active-colour "${p.text}"
      set -g clock-mode-colour "${p.text}"
    '';

  # From rose-pine/fish's "Rosé Pine" theme, role for role. Universal, so every running
  # shell picks the change up.
  fishFragment = p: let
    c = bare;
  in ''
    set -U fish_color_normal ${c p.text}
    set -U fish_color_command ${c p.iris}
    set -U fish_color_keyword ${c p.foam}
    set -U fish_color_quote ${c p.gold}
    set -U fish_color_redirection ${c p.pine}
    set -U fish_color_end ${c p.subtle}
    set -U fish_color_error ${c p.love}
    set -U fish_color_param ${c p.rose}
    set -U fish_color_comment ${c p.subtle}
    set -U fish_color_selection --reverse
    set -U fish_color_operator ${c p.text}
    set -U fish_color_escape ${c p.pine}
    set -U fish_color_autosuggestion ${c p.subtle}
    set -U fish_color_cwd ${c p.rose}
    set -U fish_color_user ${c p.gold}
    set -U fish_color_host ${c p.foam}
    set -U fish_color_host_remote ${c p.iris}
    set -U fish_color_cancel ${c p.text}
    set -U fish_color_search_match --background=${c p.base}
    set -U fish_color_valid_path
    set -U fish_pager_color_progress ${c p.rose}
    set -U fish_pager_color_background --background=${c p.surface}
    set -U fish_pager_color_prefix ${c p.foam}
    set -U fish_pager_color_completion ${c p.subtle}
    set -U fish_pager_color_description ${c p.subtle}
    set -U fish_pager_color_selected_background --background=${c p.overlay}
    set -U fish_pager_color_selected_prefix ${c p.foam}
    set -U fish_pager_color_selected_completion ${c p.text}
    set -U fish_pager_color_selected_description ${c p.text}
  '';

  # Appended to the fish fragment below: the payload the OSC handler in shell.nix
  # paints onto every running Ghostty surface — background, foreground, cursor,
  # selection background, selection foreground, as bare hex. A config reload
  # recolours only new cells and new windows; these dynamic colours are what an
  # already-open window needs.
  oscFragment = p: ''
    set -U theme_osc "${bare p.base} ${bare p.text} ${bare p.text} ${bare p.highlightMed} ${bare p.text}"
  '';

  starshipFragment = p:
    lib.recursiveUpdate config.programs.starship.settings {
      git_status = {
        conflicted = "[!](bold fg:${p.love})";
        ahead = "[⇡\${count}](bold fg:${p.foam})";
        behind = "[⇣\${count}](bold fg:${p.gold})";
        diverged = "[⇡\${ahead_count}⇣\${behind_count}](bold fg:${p.gold})";
        untracked = "[?\${count} ](fg:${p.muted})";
        stashed = "[⊙\${count} ](fg:${p.iris})";
        modified = "[!\${count} ](fg:${p.gold})";
        staged = "[+\${count} ](fg:${p.foam})";
        renamed = "[»\${count} ](fg:${p.iris})";
        deleted = "[✗\${count} ](fg:${p.love})";
      };
    };

  fzfFragment = p: ''
    --color=bg+:${p.overlay},bg:${p.base},spinner:${p.rose},hl:${p.love}
    --color=fg:${p.text},header:${p.love},info:${p.iris},pointer:${p.rose}
    --color=marker:${p.rose},fg+:${p.text},prompt:${p.iris},hl+:${p.love}
  '';

  lazygitFragment = p:
    lib.recursiveUpdate config.programs.lazygit.settings {
      gui.theme = {
        activeBorderColor = [p.love "bold"];
        inactiveBorderColor = [p.highlightMed];
        selectedLineBgColor = [p.overlay];
      };
    };

  zathuraFragment = p: ''
    set default-bg "${p.base}"
    set default-fg "${p.text}"
    set statusbar-bg "${p.surface}"
    set statusbar-fg "${p.text}"
    set inputbar-bg "${p.surface}"
    set inputbar-fg "${p.text}"
    set notification-bg "${p.surface}"
    set notification-fg "${p.text}"
    set notification-error-bg "${p.surface}"
    set notification-error-fg "${p.love}"
    set notification-warning-bg "${p.surface}"
    set notification-warning-fg "${p.gold}"
    set highlight-color "rgba(${rgbWith "," p.love},0.4)"
    set highlight-active-color "rgba(${rgbWith "," p.iris},0.4)"
    set recolor-lightcolor "${p.base}"
    set recolor-darkcolor "${p.text}"
  '';

  fuzzelFragment = p: ''
    [colors]
    background=${bare p.base}dd
    text=${bare p.text}ff
    match=${bare p.love}ff
    selection=${bare p.overlay}ff
    selection-text=${bare p.text}ff
    selection-match=${bare p.love}ff
    border=${bare p.highlightMed}ff
  '';

  # Sourced by the claude status line and gen-commit: each role as hex, and as the
  # `r;g;b` a 24-bit SGR escape wants.
  colorsFragment = p:
    lib.concatMapStrings (r: let
      name = lib.toUpper (lib.concatStringsSep "_" (lib.splitString "-" (lib.replaceStrings ["highlight"] ["highlight-"] r)));
    in ''
      THEME_${name}="${p.${r}}"
      THEME_${name}_RGB="${rgbWith ";" p.${r}}"
    '')
    roles;

  themeDir = id: let
    p = palettes.${id};
    x = extras.${id};
    text = name: pkgs.writeText "${id}-${name}";
  in
    pkgs.linkFarm "theme-${id}" {
      "hyprland.lua" = text "hyprland.lua" ''
        return {
          general = {
            col = {
              active_border = "rgba(${bare p.highlightHigh}aa)",
              inactive_border = "rgba(${bare p.overlay}aa)",
            },
          },
        }
      '';
      "ghostty" = text "ghostty" x.ghostty;
      "helix.toml" = x.helix;
      "tmux.conf" = text "tmux.conf" (tmuxFragment id p);
      "fish.fish" = text "fish.fish" (fishFragment p + oscFragment p);
      "starship.toml" = toml.generate "${id}-starship.toml" (starshipFragment p);
      "fzf" = text "fzf" (fzfFragment p);
      "bat" = text "bat" "--theme=\"${x.bat}\"\n";
      "gtk.env" = text "gtk.env" ''
        GTK_THEME_NAME=${x.gtkTheme}
        ICON_THEME_NAME=${x.iconTheme}
        COLOR_SCHEME=${x.colorScheme}
      '';
      "kvantum.kvconfig" = text "kvantum.kvconfig" ''
        [General]
        theme=${x.kvantum}
      '';
      "btop.theme" = text "btop.theme" (recolour p btopRosePine);
      "lazygit.yml" = yaml.generate "${id}-lazygit.yml" (lazygitFragment p);
      "yazi.yazi" = x.yazi;
      "zathurarc" = text "zathurarc" (zathuraFragment p);
      "fuzzel.ini" = text "fuzzel.ini" (fuzzelFragment p);
      "herdr.toml" = toml.generate "${id}-herdr.toml" (config.programs.herdr.settings // {theme.name = x.herdr;});
      "colors.sh" = text "colors.sh" (colorsFragment p);
    };

  themes = lib.genAttrs ids themeDir;

  # GTK 3 reads its theme and icons from dconf, which takes no schema lookup, so this works
  # from activation as well as from the session. The appearance colour scheme rides the same
  # dconf: the settings portal watches it and broadcasts changes, which is how Helium and the
  # libadwaita apps follow the theme live.
  setGtk = ''
    setGtk() {
      # shellcheck source=/dev/null
      . "$state/current/gtk.env"
      dconf write /org/freedesktop/appearance/color-scheme "'$COLOR_SCHEME'" &&
        dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME_NAME'" &&
        dconf write /org/gnome/desktop/interface/icon-theme "'$ICON_THEME_NAME'"
    }
  '';

  # `name`/`dir` pairs for a shell `case`, shared by the switch and by activation.
  caseArms = lib.concatMapStrings (id: "    ${id}) dir=${themes.${id}} ;;\n") ids;

  theme-switch = pkgs.writeShellApplication {
    name = "theme-switch";
    runtimeInputs = [pkgs.coreutils pkgs.procps pkgs.dconf pkgs.awww pkgs.fish pkgs.tmux];
    text = ''
      ${setGtk}
      id="''${1:-}"
      case "$id" in
      ${caseArms}    *)
          echo "usage: theme-switch <${lib.concatStringsSep "|" ids}>" >&2
          exit 2
          ;;
      esac

      state="${stateDir}"
      mkdir -p "$state"

      # Already up: nothing to move and nothing to repaint.
      if [ -e "$state/current" ] && [ "$(cat "$state/name" 2>/dev/null)" = "$id" ]; then
        exit 0
      fi

      # Renamed over the old link, so there is never a moment it does not exist.
      ln -sfn "$dir" "$state/current.new"
      mv -T "$state/current.new" "$state/current"

      # The wallpaper this theme was last used with, or the first in its folder. The link is
      # written before the name, so Quickshell, which watches the name, finds it in place.
      wallpapers="$HOME/.local/share/wallpaper"
      wallpaper=""
      if [ -e "$wallpapers/$id" ]; then
        wallpaper="$(readlink "$wallpapers/$id")"
      else
        for f in "$HOME/Pictures/backgrounds/$id"/*; do
          if [ -f "$f" ]; then
            wallpaper="$f"
            break
          fi
        done
      fi
      if [ -n "$wallpaper" ]; then
        mkdir -p "$wallpapers"
        ln -sfn "$wallpaper" "$wallpapers/current.new"
        mv -T "$wallpapers/current.new" "$wallpapers/current"
      fi

      # Written in place rather than renamed, so the file watcher keeps its inode. The shell
      # is also asked to read it, because a file created after the shell started (the first
      # activation) has no watch on it.
      printf '%s\n' "$id" >"$state/name"
      if command -v qs >/dev/null; then
        qs ipc call theme sync >/dev/null 2>&1 || true
      fi

      # Everything below is a courtesy to whatever is already running. None of it may stop
      # the switch: a program that is not up has nothing to be told.
      if [ -n "$wallpaper" ]; then
        awww img "$wallpaper" --transition-type grow --transition-pos center \
          --transition-duration 0.9 --transition-fps 120 || true
      fi

      setGtk || true

      if command -v hyprctl >/dev/null; then
        hyprctl reload >/dev/null || true
      fi
      # Ghostty runs as `.ghostty-wrapped`, so it is matched by substring. The reload
      # recolours new cells and new windows; the background, foreground, cursor and
      # selection of the windows already open are repainted by the fish OSC handler,
      # which the `theme_osc` set in the fragment below wakes.
      pkill -USR2 ghostty || true
      pkill -USR1 -x hx || true
      tmux source-file "$state/current/tmux.conf" 2>/dev/null || true
      if command -v herdr >/dev/null; then
        herdr server reload-config >/dev/null 2>&1 || true
      fi
      fish -c "source '$state/current/fish.fish'" || true
    '';
  };
in {
  home.packages = [
    theme-switch
    # The dark theme's GTK theme and icons.
    pkgs.gnome-themes-extra
    pkgs.adwaita-icon-theme
  ];

  # First run starts on Rose Pine. After that, a rebuild keeps the chosen theme and only
  # re-points the link at that theme's rebuilt directory. After dconfSettings, because that
  # writes the Rose Pine GTK names back on every activation.
  home.activation.themeState = lib.hm.dag.entryAfter ["linkGeneration" "dconfSettings"] ''
    if [ -z "''${DRY_RUN:-}" ]; then
      state="${stateDir}"
      mkdir -p "$state"
      id="$(cat "$state/name" 2>/dev/null || true)"
      case "$id" in
      ${caseArms}    *)
          id=rose-pine
          dir=${themes.rose-pine}
          ;;
      esac
      ln -sfn "$dir" "$state/current.new"
      mv -T "$state/current.new" "$state/current"
      if [ "$(cat "$state/name" 2>/dev/null)" != "$id" ]; then
        printf '%s\n' "$id" >"$state/name"
      fi

      ${pkgs.fish}/bin/fish -c "source '$state/current/fish.fish'" || true
      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        PATH="${pkgs.dconf}/bin:$PATH"
        ${setGtk}
        setGtk || true
      fi
    fi
  '';

  # Hyprland: the border colours come from the theme; see desktop.nix for the rest.
  wayland.windowManager.hyprland.extraConfig = ''
    -- The theme's border colours, re-read on every `hyprctl reload`.
    do
      local ok, theme = pcall(dofile, "${current}/hyprland.lua")
      if ok and type(theme) == "table" then
        hl.config(theme)
      end
    end
  '';

  # Ghostty and Helix read their theme through the state link; see terminal.nix and
  # editors.nix for the lines that include them.
  xdg.configFile."helix/themes/current.toml".source = link "${current}/helix.toml";

  # Programs that read one config file at a fixed path get that path pointed at the theme.
  # The starship and lazygit modules write home.file rather than xdg.configFile, so those
  # two are overridden there.
  home.file."${config.xdg.configHome}/starship.toml".source = lib.mkForce (link "${current}/starship.toml");
  xdg.configFile."bat/config".source = link "${current}/bat";
  home.file."${config.xdg.configHome}/lazygit/config.yml".source = lib.mkForce (link "${current}/lazygit.yml");
  xdg.configFile."herdr/config.toml".source = lib.mkForce (link "${current}/herdr.toml");
  xdg.configFile."Kvantum/kvantum.kvconfig".source = link "${current}/kvantum.kvconfig";
  xdg.configFile."yazi/flavors/current.yazi".source = link "${current}/yazi.yazi";

  home.sessionVariables.FZF_DEFAULT_OPTS_FILE = "${current}/fzf";

  # btop finds themes by name in its themes folder, not by path.
  programs.btop.settings.color_theme = "current";
  xdg.configFile."btop/themes/current.theme".source = link "${current}/btop.theme";
  programs.yazi.theme.flavor.dark = "current";
  programs.zathura.extraConfig = "include ${current}/zathurarc";
  programs.fuzzel.settings.main.include = "${current}/fuzzel.ini";
}
