{ config, pkgs, ... }:
{
  home.file.".config/ghostty/config".text = ''
    theme = Rose Pine

    font-family = JetBrainsMono Nerd Font
    font-style = Regular
    font-size = 11

    window-theme = ghostty
    window-padding-x = 14
    window-padding-y = 14
    confirm-close-surface = false
    gtk-toolbar-style = flat

    background-opacity = 0.75
    # Native blending keeps glyphs from thinning out over the translucent background.
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
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = rose-pine;
        extraConfig = ''
          set -g @rose_pine_variant 'main'
          set -g @rose_pine_host 'on'
          set -g @rose_pine_date_time '%Y-%m-%d %H:%M'
          set -g @rose_pine_directory 'on'
        '';
      }
      yank
    ];
    extraConfig = ''
      setw -g pane-base-index 1
      set -g renumber-windows on

      # rose-pine sets the message styles without a `fill`, and tmux clears the
      # status line behind the command prompt only as far as the fill reaches —
      # without it the window list and status-right stay visible under `:`.
      set -ag message-style ",fill=#191724"
      set -ag message-command-style ",fill=#f6c177"

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
}
