{ config, pkgs, ... }:
{
  home.file.".config/ghostty/config".text = ''
    # The colours come from the active theme (see theme.nix). Included last, so they win;
    # `?` because the file does not exist until the first activation has run.
    config-file = ?${config.home.homeDirectory}/.local/state/theme/current/ghostty

    font-family = JetBrainsMono Nerd Font
    font-style = Regular
    font-size = 12

    window-theme = ghostty
    window-padding-x = 14
    window-padding-y = 14
    confirm-close-surface = false
    gtk-toolbar-style = flat

    background-opacity = 0.75
    # herdr paints explicit cell backgrounds, which would otherwise be opaque.
    background-opacity-cells = true
    # Linear modes break Hyprland's blur behind the window.
    alpha-blending = native
    minimum-contrast = 1.1

    cursor-style = "block"
    cursor-style-blink = false

    shell-integration = fish

    keybind = shift+insert=paste_from_clipboard
    keybind = control+insert=copy_to_clipboard
    keybind = super+control+shift+alt+arrow_down=resize_split:down,100
    keybind = super+control+shift+alt+arrow_up=resize_split:up,100
    keybind = super+control+shift+alt+arrow_left=resize_split:left,100
    keybind = super+control+shift+alt+arrow_right=resize_split:right,100

    mouse-scroll-multiplier = 0.95

    # Work around Hyprland latency.
    async-backend = epoll

    resize-overlay = never
  '';

  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    terminal = "tmux-256color";
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    # The Rose Pine plugin is loaded by the theme fragment; see theme.nix.
    plugins = with pkgs.tmuxPlugins; [
      yank
    ];
    extraConfig = ''
      setw -g pane-base-index 1
      set -g renumber-windows on

      # Colours from the active theme; theme-switch re-sources this live.
      source-file -q ~/.local/state/theme/current/tmux.conf

      # send-prefix does nothing while the prefix is off, so send the key itself.
      bind -N "Send C-a" a send-prefix

      # Splits in current working directory
      bind -N "Split vertical" v split-window -h -c "#{pane_current_path}"
      bind -N "Split horizontal" s split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # New window in current path
      bind -N "New window" c new-window -c "#{pane_current_path}"

      bind -N "Go left" h select-pane -L
      bind -N "Go down" j select-pane -D
      bind -N "Go up" k select-pane -U
      bind -N "Go right" l select-pane -R

      bind -r -N "Resize left" H resize-pane -L 5
      bind -r -N "Resize down" J resize-pane -D 5
      bind -r -N "Resize up" K resize-pane -U 5
      bind -r -N "Resize right" L resize-pane -R 5

      bind -N "Reload config" r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

      bind -r -N "Move window left" "<" swap-window -d -t -1
      bind -r -N "Move window right" ">" swap-window -d -t +1

      bind -N "Sessions" S choose-tree -Zs

      # Copy mode — helix-style
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi x send-keys -X select-line
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
      bind -T copy-mode-vi Escape send-keys -X cancel
    '';
  };

  # Migrating off tmux; both stay enabled until the herdr keymap sticks.
  programs.herdr = {
    enable = true;

    settings = {
      onboarding = false;

      # `theme.name` is added per theme, and the file linked to the active one, in theme.nix.

      # `herdr update` can't overwrite a store binary, so skip the nag.
      update.version_check = false;

      terminal = {
        # tmux passed `-c "#{pane_current_path}"` on every split and window.
        new_cwd = "follow";
      };

      keys = {
        prefix = "ctrl+a";

        # Match the tmux splits; settings moves off prefix+s.
        split_vertical = "prefix+v";
        split_horizontal = "prefix+s";
        settings = "prefix+shift+s";

        # tmux detached with prefix+d; herdr defaults to prefix+q.
        detach = "prefix+d";

        # focus_pane_{left,down,up,right} already default to prefix+h/j/k/l.

        # herdr has a modal resize mode instead of per-direction binds.
        resize_mode = "prefix+r";
      };

      ui = {
        # tmux's new-window does not ask for a name.
        prompt_new_tab_name = false;
      };

      # tmux counted 50000 scrollback lines; herdr counts bytes.
      advanced.scrollback_limit_bytes = 20000000;
    };
  };
}
