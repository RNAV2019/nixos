{ config, pkgs, ... }:
{
  # Ghostty terminal config stored at ~/.config/ghostty/config
  home.file.".config/ghostty/config".text = ''
    # Monochrome + red theme
    background = #0d0d0d
    foreground = #c8c8c8
    cursor-color = #c8c8c8
    selection-background = #303030
    selection-foreground = #c8c8c8

    palette = 0=#1a1a1a
    palette = 1=#cc3333
    palette = 2=#888888
    palette = 3=#aaaaaa
    palette = 4=#999999
    palette = 5=#bbbbbb
    palette = 6=#cccccc
    palette = 7=#e0e0e0
    palette = 8=#333333
    palette = 9=#e05555
    palette = 10=#aaaaaa
    palette = 11=#cccccc
    palette = 12=#bbbbbb
    palette = 13=#dddddd
    palette = 14=#e0e0e0
    palette = 15=#f0f0f0

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

  # Setup tmux after
  # programs.tmux = {};  
}
