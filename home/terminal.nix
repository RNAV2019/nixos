{ config, pkgs, ... }:
{
  # Ghostty terminal config stored at ~/.config/ghostty/config
  home.file.".config/ghostty/config".text = ''
    # Rose Pine theme (Ghostty built-in)
    theme = Rose Pine

    # Font
    font-family = JetBrainsMono Nerd Font
    font-style = Regular
    font-size = 9

    # Window
    window-theme = ghostty
    window-padding-x = 14
    window-padding-y = 14
    confirm-close-surface = false
    gtk-toolbar-style = flat

    # Opacity
    background-opacity = 0.75

    # Cursor Styling
    cursor-style = "block"
    cursor-style-blink = false

    shell-integration = fish

    keybind = shift+insert=paste_from_clipboard
    keybind = control+insert=copy_to_clipboard
    keybind = super+control+shift+alt+arrow_down=resize_split:down,100
    keybind = super+control+shift+alt+arrow_up=resize_split:up,100
    keybind = super+control+shift+alt+arrow_left=resize_split:left,100
    keybind = super+control+shift+alt+arrow_right=resize_split:right,100

    # Slowdown mouse scrolling
    mouse-scroll-multiplier = 0.95

    # Fix slowness on hyprland
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

      # Send literal Ctrl+a (beginning-of-line) with prefix+a
      bind a send-prefix

      # Splits in current working directory
      bind v split-window -h -c "#{pane_current_path}"
      bind s split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # New window in current path
      bind c new-window -c "#{pane_current_path}"

      # Pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Pane resize
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

      # Window movement
      bind -r "<" swap-window -d -t -1
      bind -r ">" swap-window -d -t +1

      # Session picker
      bind S choose-tree -Zs

      # Copy mode — helix-style
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi x send-keys -X select-line
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
      bind -T copy-mode-vi Escape send-keys -X cancel
    '';
  };
}
