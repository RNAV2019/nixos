{ config, ... }:
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

  programs.herdr = {
    enable = true;

    settings = {
      onboarding = false;

      # `theme.name` is added per theme, and the file linked to the active one, in theme.nix.

      # `herdr update` can't overwrite a store binary, so skip the nag.
      update.version_check = false;

      terminal = {
        # New panes follow the current directory.
        new_cwd = "follow";
      };

      keys = {
        prefix = "ctrl+a";

        # settings moves off prefix+s.
        split_vertical = "prefix+v";
        split_horizontal = "prefix+s";
        settings = "prefix+shift+s";

        # herdr defaults to prefix+q.
        detach = "prefix+d";

        # focus_pane_{left,down,up,right} already default to prefix+h/j/k/l.

        # herdr has a modal resize mode instead of per-direction binds.
        resize_mode = "prefix+r";
      };

      ui = {
        # Don't prompt for a new tab name.
        prompt_new_tab_name = false;
      };

      # herdr counts scrollback in bytes.
      advanced.scrollback_limit_bytes = 20000000;
    };
  };
}
