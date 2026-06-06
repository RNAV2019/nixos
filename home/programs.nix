{ config, pkgs, ... }:
{
  # Tealdeer (tldr) — auto-update cache so pages are always available
  programs.tealdeer = {
    enable = true;
    settings = {
      updates = {
        auto_update = true;
        auto_update_interval_hours = 168;
      };
    };
  };

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

    flavors = {
      rose-pine = "${pkgs.fetchFromGitHub {
        owner = "rose-pine";
        repo = "yazi";
        rev = "c89d745573d4fcfe0550fe6646f9f9ab1c0e51db";
        hash = "sha256-9e3dXViWl1rK9BPrGAFfs9ZL/tsG6Njz6ksuU6AIrFY=";
      }}/flavors/rose-pine.yazi";
    };

    theme = {
      flavor.dark = "rose-pine";
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
      default-bg                = "#191724";
      default-fg                = "#e0def4";
      statusbar-bg              = "#1f1d2e";
      statusbar-fg              = "#e0def4";
      inputbar-bg               = "#1f1d2e";
      inputbar-fg               = "#e0def4";
      notification-bg           = "#1f1d2e";
      notification-fg           = "#e0def4";
      notification-error-bg     = "#1f1d2e";
      notification-error-fg     = "#eb6f92";
      notification-warning-bg   = "#1f1d2e";
      notification-warning-fg   = "#f6c177";
      highlight-color           = "rgba(235,111,146,0.4)";
      highlight-active-color    = "rgba(196,167,231,0.4)";
      recolor-lightcolor        = "#191724";
      recolor-darkcolor         = "#e0def4";
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

  # Lazygit
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor   = [ "#eb6f92" "bold" ];
          inactiveBorderColor = [ "#403d52" ];
          selectedLineBgColor = [ "#26233a" ];
        };
        nerdFontsVersion = "3";
      };
      git = {
        pager = "delta --dark --paging=never";
      };
    };
  };

  # Btop
  programs.btop = {
    enable = true;
    settings = {
      color_theme      = "rose-pine";
      theme_background = false;
      vim_keys         = true;
      rounded_corners  = true;
      update_ms        = 1000;
    };
  };

  xdg.configFile."btop/themes/rose-pine.theme".text = ''
    theme[main_bg]="#191724"
    theme[main_fg]="#e0def4"
    theme[title]="#e0def4"
    theme[hi_fg]="#eb6f92"
    theme[selected_bg]="#26233a"
    theme[selected_fg]="#eb6f92"
    theme[inactive_fg]="#6e6a86"
    theme[graph_text]="#908caa"
    theme[meter_bg]="#26233a"
    theme[proc_misc]="#c4a7e7"
    theme[cpu_box]="#403d52"
    theme[mem_box]="#403d52"
    theme[net_box]="#403d52"
    theme[proc_box]="#403d52"
    theme[div_line]="#26233a"
    theme[temp_start]="#9ccfd8"
    theme[temp_mid]="#f6c177"
    theme[temp_end]="#eb6f92"
    theme[cpu_start]="#9ccfd8"
    theme[cpu_mid]="#c4a7e7"
    theme[cpu_end]="#eb6f92"
    theme[free_start]="#31748f"
    theme[free_mid]="#9ccfd8"
    theme[free_end]="#e0def4"
    theme[cached_start]="#403d52"
    theme[cached_mid]="#6e6a86"
    theme[cached_end]="#908caa"
    theme[available_start]="#9ccfd8"
    theme[available_mid]="#c4a7e7"
    theme[available_end]="#e0def4"
    theme[used_start]="#f6c177"
    theme[used_mid]="#ebbcba"
    theme[used_end]="#eb6f92"
    theme[download_start]="#31748f"
    theme[download_mid]="#9ccfd8"
    theme[download_end]="#e0def4"
    theme[upload_start]="#f6c177"
    theme[upload_mid]="#ebbcba"
    theme[upload_end]="#eb6f92"
    theme[process_start]="#31748f"
    theme[process_mid]="#c4a7e7"
    theme[process_end]="#eb6f92"
  '';
}
