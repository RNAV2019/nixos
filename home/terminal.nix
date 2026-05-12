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
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = rose-pine;
        extraConfig = ''
          set -g @rose_pine_variant 'main'
        '';
      }
    ];
  };
}
