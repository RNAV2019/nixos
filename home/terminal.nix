{ config, pkgs, ... }:
{
  home.file.".config/ghostty/config".text = ''
    theme = Rose Pine

    font-family = JetBrainsMono Nerd Font
    font-style = Regular
    # 163 DPI draws a glyph with well under half the pixels the old 2880x1800
    # panel gave it, so buy some of them back with size.
    font-size = 12

    window-theme = ghostty
    window-padding-x = 14
    window-padding-y = 14
    confirm-close-surface = false
    gtk-toolbar-style = flat

    background-opacity = 0.75
    # herdr paints its panes with an explicit background (rose-pine surface,
    # #1f1d2e) rather than leaving the terminal default. Ghostty applies
    # background-opacity only to the default background, so those cells come
    # out fully opaque and Hyprland sees nothing translucent to blur. tmux did
    # not set one, which is why the blur survived until the migration.
    background-opacity-cells = true
    # Must stay `native`: linear modes blend the background-opacity into an
    # opaque intermediate buffer, and the compositor only sees a uniform alpha
    # with no per-pixel edges, so Hyprland's blur never applies to the window.
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

  # Migrating off tmux; both stay enabled until the herdr keymap sticks.
  programs.herdr = {
    enable = true;

    settings = {
      onboarding = false;

      # Built in, so this needs no plugin the way tmux's rose-pine did.
      theme.name = "rose-pine";

      # `herdr update` writes over its own binary, which the Nix store will
      # not allow, so suppress the nag. The agent-detection manifest check is
      # plain data and stays on.
      update.version_check = false;

      terminal = {
        # tmux passed `-c "#{pane_current_path}"` on every split and window.
        new_cwd = "follow";
      };

      keys = {
        prefix = "ctrl+a";

        # `v` splits vertically and `s` horizontally, as in the tmux config.
        # herdr puts split_horizontal on prefix+minus and settings on prefix+s.
        split_vertical = "prefix+v";
        split_horizontal = "prefix+s";
        settings = "prefix+shift+s";

        # tmux detached with prefix+d; herdr defaults to prefix+q.
        detach = "prefix+d";

        # focus_pane_{left,down,up,right} already default to prefix+h/j/k/l.

        # tmux resized with `H/J/K/L`. herdr has no per-direction resize
        # bindings; it enters a modal resize mode instead.
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
