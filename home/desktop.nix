{
  config,
  pkgs,
  hyprland,
  ...
}: {
  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    # UWSM owns the user systemd session.
    systemd.enable = false;

    settings = {
      monitor = [
        "eDP-1,2880x1800@60,0x0,1.6"
      ];

      # Block bindings and helpers until Quickshell secures every output.
      exec-once = [
        "hyprctl dispatch submap lockdown && start-desktop"
      ];

      env = [
        "XCURSOR_SIZE,24"
        "XCURSOR_THEME,Bibata-Modern-Classic"
        "HYPRCURSOR_SIZE,24"
        "NIXOS_OZONE_WL,1"
        "XDG_SCREENSHOTS_DIR,$HOME/Pictures/screenshots"
        "LD_LIBRARY_PATH,${pkgs.lib.makeLibraryPath [pkgs.wayland pkgs.libxkbcommon pkgs.vulkan-loader]}"
      ];

      input = {
        kb_layout = "gb";
        follow_mouse = 1;
        mouse_refocus = false;
        touchpad = {
          natural_scroll = false;
          tap-to-click = true;
          scroll_factor = 0.5;
        };
        sensitivity = 0;
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;

        border_size = 2;

        "col.active_border" = "rgba(524f67aa)";
        "col.inactive_border" = "rgba(26233aaa)";

        resize_on_border = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 6;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          vibrancy = 0.1696;
        };
        shadow.enabled = false;
      };

      # Omarchy preset.
      animations = {
        enabled = true;
        bezier = [
          "easeOutQuint, 0.23, 1, 0.32, 1"
          "easeInOutCubic, 0.65, 0.05, 0.36, 1"
          "linear, 0, 0, 1, 1"
          "almostLinear, 0.5, 0.5, 0.75, 1.0"
          "quick, 0.15, 0, 0.1, 1"
        ];
        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 0, 1, default"
          "workspacesIn, 0, 1, default"
          "workspacesOut, 0, 1, default"
        ];
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        # Covers the handoff from Plymouth to the lock surface.
        background_color = "rgba(191724ff)";
      };

      "$mod" = "SUPER";

      bind = [
        "$mod, RETURN, exec, ghostty"
        "$mod SHIFT, B, exec, helium"
        "$mod SHIFT, F, exec, nautilus"
        "$mod, P, exec, project-picker --toggle"

        "$mod, W, killactive"
        "$mod, T, toggleFloating"
        "$mod, J, layoutmsg, togglesplit"
        "$mod, F, fullscreen, 0"

        "$mod, LEFT, movefocus, l"
        "$mod, RIGHT, movefocus, r"
        "$mod, UP, movefocus, u"
        "$mod, DOWN, movefocus, d"

        "$mod SHIFT, LEFT, swapwindow, l"
        "$mod SHIFT, RIGHT, swapwindow, r"
        "$mod SHIFT, UP, swapwindow, u"
        "$mod SHIFT, DOWN, swapwindow, d"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # Match Omarchy screenshot bindings.
        ", Print, exec, grimblast --notify copysave area"
        "ALT, Print, exec, grimblast --notify copysave output"
        "$mod, Print, exec, pkill hyprpicker || hyprpicker -a"
        "$mod CTRL, Print, exec, grimblast --notify copysave screen"

        "$mod, L, exec, lock-session"

        "$mod, ESCAPE, exec, qs ipc call session toggle"

        # Match bar panel shortcuts.
        "$mod CTRL, A, exec, qs ipc call panels toggle audio"
        "$mod CTRL, W, exec, qs ipc call panels toggle network"
        "$mod CTRL, B, exec, qs ipc call panels toggle bluetooth"
        "$mod CTRL, P, exec, qs ipc call panels toggle battery"
        "$mod CTRL, S, exec, qs ipc call panels toggle system"
        "$mod CTRL, C, exec, qs ipc call panels toggle clock"

        "$mod, SPACE, exec, mycelium --toggle"

        "CTRL SUPER, SPACE, exec, cherry --toggle"

        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Quickshell watches these controls and renders the OSD.
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      windowrule = [
        "match:class uk.co.ryannavsaria.project-picker, float on"
        "match:class uk.co.ryannavsaria.project-picker, center on"
        "match:class uk.co.ryannavsaria.project-picker, border_size 0"
        "match:class uk.co.ryannavsaria.project-picker, rounding 18"

        "match:class uk.co.ryannavsaria.mycelium, float on"
        "match:class uk.co.ryannavsaria.mycelium, center on"
        "match:class uk.co.ryannavsaria.mycelium, border_size 0"
        "match:class uk.co.ryannavsaria.mycelium, rounding 18"

        "match:class uk.co.ryannavsaria.cherry, float on"
        "match:class uk.co.ryannavsaria.cherry, center on"
        "match:class uk.co.ryannavsaria.cherry, border_size 0"
        "match:class uk.co.ryannavsaria.cherry, rounding 18"

        "match:class org.pwmt.zathura, no_initial_focus on"

        "match:class mpv, float on"
        "match:class mpv, center on"
      ];

      # Bar panels are opaque xdg popups; only the session layer needs blur.
      layerrule = [
        "blur on, match:namespace quickshell-session"
      ];
    };

    # The catchall registers lockdown and blocks normal startup bindings.
    extraConfig = ''
      submap = lockdown
      bind = , catchall, exec, true
      submap = reset
    '';
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=12";
        width = 28;
        lines = 8;
        horizontal-pad = 14;
        vertical-pad = 8;
        inner-pad = 4;
        placeholder = "Launch...";
        icons-enabled = "no";
      };
      colors = {
        background = "191724dd";
        text = "e0def4ff";
        match = "eb6f92ff";
        selection = "26233aff";
        selection-text = "e0def4ff";
        selection-match = "eb6f92ff";
        border = "403d52ff";
      };
      border = {
        width = 1;
        radius = 8;
      };
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # before_sleep_cmd raises the event that runs lock_cmd.
        lock_cmd = "lock-session";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
    };
  };

  # Out-of-store symlink enables QML hot reload without rebuilding.
  programs.quickshell.enable = true;

  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/quickshell";
}
