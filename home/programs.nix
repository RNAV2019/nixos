{ config, pkgs, ... }:
{
  # Yazi
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;

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

    theme = {
      filetype = {
        rules = [
          { mime = "image/*"; fg = "#89dceb"; }
          { mime = "video/*"; fg = "#f38ba8"; }
          { mime = "audio/*"; fg = "#a6e3a1"; }
          { mime = "application/zip"; fg = "#f9e2af"; }
          { mime = "application/gzip"; fg = "#f9e2af"; }
        ];
      };
    };

    keymap = {
      manager.prepend_keymap = [
        { on = [ "T" ]; run = "shell ghostty &"; desc = "Open terminal here"; }
      ];
    };
  };

  # Zathura
  programs.zathura = {
    enable = true;
    options = {
      default-bg = "#1e1e2e";
      default-fg = "#cdd6f4";
      statusbar-bg = "#181825";
      statusbar-fg = "#cdd6f4";
      inputbar-bg = "#181825";
      inputbar-fg = "#cdd6f4";
      notification-bg = "#181825";
      notification-fg = "#cdd6f4";
      notification-error-bg = "#181825";
      notification-error-fg = "#f38ba8";
      notification-warning-bg = "#181825";
      notification-warning-fg = "#f9e2af";
      highlight-color = "rgba(203,166,247,0.5)";
      highlight-active-color = "rgba(137,180,250,0.5)";
      recolor-lightcolor = "#1e1e2e";
      recolor-darkcolor = "#cdd6f4";
      recolor = true;
      recolor-keephue = true;

      scroll-step = 50;
      zoom-min = 10;
      guioptions = "";
      font = "JetBrainsMono Nerd Font 11";
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

  # Lazygit
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor = [ "#89b4fa" "bold" ];
          inactiveBorderColor = [ "#6c7086" ];
          selectedLineBgColor = [ "#313244" ];
        };
        nerdFontsVersion = "3";
      };
      git = {
        paging = {
          colorArg = "always";
          pager = "delta --dark --paging=never";
        };
      };
    };
  };

  # Btop
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "catppuccin_mocha";
      theme_background = false;
      vim_keys = true;
      rounded_corners = true;
      update_ms = 1000;
    };
  };
}
