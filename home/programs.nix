{ config, pkgs, ... }:
{
  # Yazi
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

    theme = {
      filetype = {
        rules = [
          { mime = "image/*";          fg = "#c8c8c8"; }
          { mime = "video/*";          fg = "#cc3333"; }
          { mime = "audio/*";          fg = "#aaaaaa"; }
          { mime = "application/zip";  fg = "#888888"; }
          { mime = "application/gzip"; fg = "#888888"; }
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
      default-bg                = "#0d0d0d";
      default-fg                = "#c8c8c8";
      statusbar-bg              = "#141414";
      statusbar-fg              = "#c8c8c8";
      inputbar-bg               = "#141414";
      inputbar-fg               = "#c8c8c8";
      notification-bg           = "#141414";
      notification-fg           = "#c8c8c8";
      notification-error-bg     = "#141414";
      notification-error-fg     = "#cc3333";
      notification-warning-bg   = "#141414";
      notification-warning-fg   = "#aaaaaa";
      highlight-color           = "rgba(204,51,51,0.4)";
      highlight-active-color    = "rgba(200,200,200,0.4)";
      recolor-lightcolor        = "#0d0d0d";
      recolor-darkcolor         = "#c8c8c8";
      recolor                   = true;
      recolor-keephue           = true;

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

  # Lazygit
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor   = [ "#cc3333" "bold" ];
          inactiveBorderColor = [ "#555555" ];
          selectedLineBgColor = [ "#2a2a2a" ];
        };
        nerdFontsVersion = "3";
      };
      git = {
        pagers = [
          {
            colorArg = "always";
            pager    = "delta --dark --paging=never";
          }
        ];
      };
    };
  };

  # Btop
  programs.btop = {
    enable = true;
    settings = {
      color_theme      = "mono-red";
      theme_background = false;
      vim_keys         = true;
      rounded_corners  = true;
      update_ms        = 1000;
    };
  };

  xdg.configFile."btop/themes/mono-red.theme".text = ''
    theme[main_bg]="#0d0d0d"
    theme[main_fg]="#c8c8c8"
    theme[title]="#c8c8c8"
    theme[hi_fg]="#cc3333"
    theme[selected_bg]="#2a2a2a"
    theme[selected_fg]="#c8c8c8"
    theme[inactive_fg]="#555555"
    theme[graph_text]="#c8c8c8"
    theme[meter_bg]="#2a2a2a"
    theme[proc_misc]="#c8c8c8"
    theme[cpu_box]="#555555"
    theme[mem_box]="#444444"
    theme[net_box]="#666666"
    theme[proc_box]="#cc3333"
    theme[div_line]="#2a2a2a"
    theme[temp_start]="#888888"
    theme[temp_mid]="#aaaaaa"
    theme[temp_end]="#cc3333"
    theme[cpu_start]="#555555"
    theme[cpu_mid]="#888888"
    theme[cpu_end]="#cc3333"
    theme[free_start]="#555555"
    theme[free_mid]="#777777"
    theme[free_end]="#aaaaaa"
    theme[cached_start]="#444444"
    theme[cached_mid]="#666666"
    theme[cached_end]="#888888"
    theme[available_start]="#888888"
    theme[available_mid]="#aaaaaa"
    theme[available_end]="#c8c8c8"
    theme[used_start]="#cc3333"
    theme[used_mid]="#aa2222"
    theme[used_end]="#881111"
    theme[download_start]="#555555"
    theme[download_mid]="#888888"
    theme[download_end]="#c8c8c8"
    theme[upload_start]="#cc3333"
    theme[upload_mid]="#aa2222"
    theme[upload_end]="#881111"
    theme[process_start]="#555555"
    theme[process_mid]="#888888"
    theme[process_end]="#cc3333"
  '';
}
