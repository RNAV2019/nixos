{ config, pkgs, ... }:
{
  programs.tealdeer = {
    enable = true;
    settings = {
      updates = {
        auto_update = true;
        auto_update_interval_hours = 168;
      };
    };
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

    settings = {
      manager = {
        show_hidden = true;
        show_symlink = true;
        sort_by = "natural";
        sort_dir_first = true;
      };

      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
      };
    };

    # The flavour is flavors/current.yazi, linked to the active theme in theme.nix.

    keymap = {
      manager.prepend_keymap = [
        { on = [ "T" ]; run = "shell ghostty &"; desc = "Open terminal here"; }
      ];
    };
  };

  programs.zathura = {
    enable = true;
    options = {
      # The colours are included from the active theme; see theme.nix.
      recolor                   = false;
      recolor-keephue           = false;

      scroll-step = 50;
      zoom-min    = 10;
      guioptions  = "";
      font        = "JetBrainsMono Nerd Font 11";
    };
    mappings = {
      "f" = "toggle_fullscreen";
      "r" = "reload";
      "R" = "rotate";
      "K" = "zoom in";
      "J" = "zoom out";
      "i" = "recolor";
    };
  };

  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        # `theme` is added per theme in theme.nix, which links config.yml to the result.
        nerdFontsVersion = "3";
      };
      git = {
        pager = "delta --dark --paging=never";
      };
    };
  };

  programs.btop = {
    enable = true;
    settings = {
      # color_theme is the active theme's file; see theme.nix.
      theme_background = false;
      vim_keys         = true;
      rounded_corners  = true;
      update_ms        = 1000;
    };
  };
}
