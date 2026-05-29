{
  pkgs,
  hyprland,
  ...
}: {
  # Hyprland config
  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    # Prevent conflict with UWSM and systemd
    systemd.enable = false;

    settings = {
      # Monitor configuration
      monitor = [
        "eDP-1,2880x1800@60,0x0,1.6"
        "DP-2,2560x1440@60,auto,1"
      ];

      workspace = [
        "5,monitor:DP-2"
      ];

      # Autostart — hyprlock paints first so there's no flash of unlocked desktop.
      exec-once = [
        "hyprlock --grace 0 & sleep 0.2 && awww-daemon"
        "awww img ~/.local/share/wallpaper/current"
        "waybar"
        "swayosd-server"
        "nm-applet --indicator"
        "cliphist wipe"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,24"
        "XCURSOR_THEME,Bibata-Modern-Classic"
        "HYPRCURSOR_SIZE,24"
        "NIXOS_OZONE_WL,1"
        "HYPRSHOT_DIR,$HOME/Pictures/screenshots"
      ];

      # Input
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

      # General appearance
      general = {
        gaps_in = 5;
        gaps_out = 10;

        border_size = 2;

        "col.active_border" = "rgba(524f67aa)";
        "col.inactive_border" = "rgba(26233aaa)";

        resize_on_border = false;
        layout = "dwindle";
      };

      # Decoration
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

      # Animations (Omarchy)
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

      # Layouts
      dwindle = {
        preserve_split = true;
        force_split = 2;
      };

      # Misc
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        # Rose Pine base — covers any frame before hyprlock/wallpaper paint
        background_color = "rgba(191724ff)";
      };

      # Keybinds
      "$mod" = "SUPER";

      bind = [
        # Apps
        "$mod, RETURN, exec, ghostty"
        "$mod SHIFT, B, exec, helium"
        "$mod SHIFT, F, exec, nautilus"

        # Window Management
        "$mod, W, killactive"
        "$mod, T, toggleFloating"
        "$mod, J, layoutmsg, togglesplit"
        "$mod, F, fullscreen, 0"

        # Focus
        "$mod, LEFT, movefocus, l"
        "$mod, RIGHT, movefocus, r"
        "$mod, UP, movefocus, u"
        "$mod, DOWN, movefocus, d"

        # Move windows
        "$mod SHIFT, LEFT, swapwindow, l"
        "$mod SHIFT, RIGHT, swapwindow, r"
        "$mod SHIFT, UP, swapwindow, u"
        "$mod SHIFT, DOWN, swapwindow, d"

        # Workspaces
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

        # Screenshots
        ", Print, exec, hyprshot -m window"
        "SHIFT, Print, exec, hyprshot -m output"
        "$mod, Print, exec, hyprshot -m region"

        # Lock screen
        "$mod, L, exec, hyprlock"

        # Logout menu
        "$mod, ESCAPE, exec, pkill wlogout || wlogout --buttons-per-row 1 --column-spacing 0 --row-spacing 4 --margin-top 450 --margin-bottom 450 --margin-left 0 --margin-right 0"

        # Clipboard history
        # "$mod, C, cliphist list | fzf | cliphist decode | wl-copy"

        # Launcher (toggle)
        "$mod, SPACE, exec, pkill fuzzel || fuzzel"

        # Wallpaper picker
        "CTRL SUPER, SPACE, exec, pkill fuzzel || fuzzel-bg-switch"

        # Media keys
        ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Media keys (repeatable)
      bindel = [
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
        ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
        ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
      ];

      # Window rules
      windowrule = [
        "match:class uk.co.ryannavsaria.project-picker, float on"
        "match:class uk.co.ryannavsaria.project-picker, center on"
        "match:class uk.co.ryannavsaria.project-picker, border_size 0"
        "match:class uk.co.ryannavsaria.project-picker, rounding 18"

        "match:class org.pwmt.zathura, no_initial_focus on"

        "match:class uk.co.ryannavsaria.bluetui-popup, float on"
        "match:class uk.co.ryannavsaria.bluetui-popup, center on"
        "match:class uk.co.ryannavsaria.bluetui-popup, size 900 600"

        "match:class uk.co.ryannavsaria.btop-popup, float on"
        "match:class uk.co.ryannavsaria.btop-popup, center on"
        "match:class uk.co.ryannavsaria.btop-popup, size 900 600"

        "match:class uk.co.ryannavsaria.wlctl-popup, float on"
        "match:class uk.co.ryannavsaria.wlctl-popup, center on"
        "match:class uk.co.ryannavsaria.wlctl-popup, size 900 600"

        "match:class uk.co.ryannavsaria.wiremix-popup, float on"
        "match:class uk.co.ryannavsaria.wiremix-popup, center on"
        "match:class uk.co.ryannavsaria.wiremix-popup, size 900 600"
      ];

      layerrule = [
        "blur on, match:namespace wlogout"
      ];
    };
  };

  # Fuzzel
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
        placeholder = "Launch or calculate...";
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

  # Waybar
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        reload_style_on_change = true;
        layer = "top";
        position = "top";
        spacing = 0;
        height = 26;
        margin-top = 6;

        modules-left = ["custom/nix" "clock" "mpris"];
        modules-center = ["hyprland/workspaces"];
        modules-right = ["group/tray-expander" "bluetooth" "network" "pulseaudio" "cpu" "battery"];

        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{icon}";
          format-icons = {
            default = "";
            active = "";
            urgent = "";
          };
          persistent-workspaces = {
            "*" = [1 2 3 4 5];
          };
          all-outputs = true;
          sort-by-number = true;
        };

        mpris = {
          format = "󰎇 {dynamic}";
          format-paused = "󰏤 {dynamic}";
          format-stopped = "";
          ignored-players = [
            "blanket"
            "Blanket"
            "com.rafaelmardojai.Blanket"
          ];
          dynamic-len = 40;
          dynamic-importance-order = ["title" "artist" "position" "length"];
        };

        "custom/nix" = {
          format = "❄";
          tooltip = false;
          on-click = "pkill wlogout || wlogout --buttons-per-row 1 --column-spacing 0 --row-spacing 4 --margin-top 450 --margin-bottom 450 --margin-left 0 --margin-right 0";
        };

        cpu = {
          interval = 5;
          format = "󰍛";
          on-click = "ghostty --class=uk.co.ryannavsaria.btop-popup -e btop";
        };

        clock = {
          format = "󰃭 {:L%d %B %Y   %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='#f6c177'><b>{}</b></span>";
              days = "<span color='#e0def4'><b>{}</b></span>";
              weeks = "<span color='#9ccfd8'><b>W{}</b></span>";
              weekdays = "<span color='#908caa'><b>{}</b></span>";
              today = "<span color='#eb6f92'><b><u>{}</u></b></span>";
            };
          };
        };

        network = {
          format-icons = ["󰤯" "󰤟" "󰤢" "󰤥" "󰤨"];
          format = "{icon}  {essid}";
          format-wifi = "{icon}  {essid}";
          format-ethernet = "󰀂";
          format-disconnected = "󰤮";
          tooltip-format-wifi = "{essid} ({frequency} GHz)";
          tooltip-format-ethernet = "Connected";
          tooltip-format-disconnected = "Disconnected";
          interval = 3;
          spacing = 1;
          on-click = "ghostty --class=uk.co.ryannavsaria.wlctl-popup -e wlctl";
        };

        battery = {
          format = "{capacity}% {icon}";
          format-discharging = "{capacity}% {icon}";
          format-charging = "{icon}";
          format-plugged = "";
          format-fill = "󰂅";
          format-icons = {
            charging = [
              "󰢜"
              "󰂆"
              "󰂇"
              "󰂈"
              "󰢝"
              "󰂉"
              "󰢞"
              "󰂊"
              "󰂋"
              "󰂅"
            ];
            default = [
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
          };
          tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
          tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
          interval = 5;
          states = {
            warning = 20;
            critical = 10;
          };
        };

        bluetooth = {
          format = "";
          format-disabled = "󰂲";
          format-off = "󰂲";
          format-connected = "󰂱";
          format-no-controller = "";
          tooltip-format = "Devices connected: {num_connections}";
          on-click = "ghostty --class=uk.co.ryannavsaria.bluetui-popup -e bluetui";
        };

        pulseaudio = {
          format = "{icon}";
          on-click = "ghostty --class=uk.co.ryannavsaria.wiremix-popup -e wiremix";
          tooltip-format = "Playing at {volume}%";
          scroll-step = 5;
          format-muted = "";
          format-icons = {
            headphone = "";
            default = ["" " " " "];
          };
        };

        "group/tray-expander" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 600;
            children-class = "tray-group-item";
          };
          modules = [
            "custom/expand-icon"
            "tray"
          ];
        };

        "custom/expand-icon" = {
          format = "";
          tooltip = false;
        };

        tray = {
          icon-size = 12;
          spacing = 17;
        };
      };
    };

    style = ''
      * {
        background: transparent;
        border: none;
        border-radius: 0;
        min-height: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 12px;
        color: #e0def4;
      }

      .modules-left {
        border-radius: 999px;
        margin-left: 3px;
      }

      .modules-center {
        border-radius: 999px;
      }

      .modules-right {
        border-radius: 999px;
        margin-right: 9px;
        padding: 0 8px;
        background: #191724;
      }

      #workspaces {
        padding: 5px 4px;
        border-radius: 18px;
        background: #191724;
      }

      #workspaces button {
        padding: 0 4px;
        margin: 0 3px;
        min-width: 12px;
        border-radius: 16px;
        background-color: #26233a;
        color: #6e6a86;
        transition: all 150ms ease-in-out;
      }

      #workspaces button.active {
        background-color: #eb6f92;
        color: #191724;
        min-width: 28px;
        border-radius: 999px;
        transition: all 150ms ease-in-out;
      }

      #workspaces button:hover {
        background-color: #403d52;
        color: #e0def4;
      }

      #cpu,
      #battery,
      #pulseaudio,
      #network,
      #bluetooth {
        margin: 0 6px;
      }

      #tray {
        margin-right: 6px;
      }

      #custom-expand-icon {
        margin-right: 6px;
        margin-left: 4px;
      }

      tooltip {
        border-radius: 8px;
        padding: 10px 14px;
        background: #191724;
        border: 1px solid #26233a;
        font-size: 13px;
      }

      #tray menu {
        border-radius: 8px;
        padding: 2px;
        background: #191724;
      }

      #mpris:not(.stopped) {
        margin-left: 8px;
      }

      .hidden {
        opacity: 0;
      }

      #custom-nix {
        padding: 5px 7px;
        border-radius: 50%;
        background: #191724;
        color: #eb6f92;
        font-size: 15px;
        margin-left: 8px;
        margin-right: 8px;
        min-width: 15px;
      }

      #clock {
        padding: 0 14px;
        border-radius: 999px;
        background: #191724;
        color: #f6c177;
      }

      #mpris {
        border-radius: 999px;
        color: #9ccfd8;
      }

      #mpris.playing,
      #mpris.paused {
        padding: 0 12px;
        background: #191724;
        font-style: normal;
      }
    '';
  };

  # Hyprlock
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        ignore_empty_input = true;
        disable_loading_bar = true;
        hide_cursor = true;
        no_fade_in = false;
        no_fade_out = false;
        grace = 0;
      };

      background = [
        {
          monitor = "";
          color = "rgba(25,23,36,1.0)";
          path = "~/.local/share/wallpaper/current";
          blur_passes = 3;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0;
        }
      ];

      animations = [
        {
          enabled = true;
        }
      ];

      label = [
        {
          monitor = "";
          text = ''cmd[update:1000] echo -e "$(date +"%A, %B, %d")"'';
          color = "rgba(224,222,244,1.0)";
          font_size = 25;
          font_family = "Inter Bold";
          position = "0, 250";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:1000] echo -e "<span>$(date +"%H:%M")</span>"'';
          color = "rgba(224,222,244,1.0)";
          font_size = 150;
          font_family = "Inter Bold";
          position = "0, 135";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "cmd[update:1000] hyprlock-music";
          color = "rgba(144,140,170,1.0)";
          font_size = 18;
          font_family = "Inter Bold";
          position = "0, 50";
          halign = "center";
          valign = "bottom";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "400, 100";
          position = "0, -80";
          halign = "center";
          valign = "center";

          inner_color = "rgba(25,23,36,0.8)";
          outer_color = "rgba(235,111,146,1.0)";
          outline_thickness = 2;

          font_family = "Inter Bold";
          font_color = "rgba(224,222,244,1.0)";

          placeholder_text = "<span>Enter Password  󰈷 </span>";
          check_color = "rgba(196,167,231,1.0)";
          fail_text = "<i>$FAIL ($ATTEMPTS)</i>";
          dots_spacing = 0.3;
          dots_size = 0.2;

          shadow_passes = 0;
          fade_on_empty = false;
        }
      ];

      auth."fingerprint:enabled" = true;
    };
  };

  # Mako - notification daemon
  services.mako = {
    enable = true;
    settings = {
      background-color = "#191724";
      text-color = "#e0def4";
      border-color = "#26233a";
      padding = "20,16";
      border-size = 1;
      border-radius = 4;
      anchor = "top-right";
      default-timeout = 5000;
      width = 420;
      max-icon-size = 32;
      max-visible = 3;
      group-by = "app-name";
      margin = "12,16,0,0";
      outer-margin = "0";
      font = "JetBrainsMono Nerd Font";
      on-button-left = "invoke-default-action";
    };
  };

  # SwayOSD — volume/brightness OSD theming
  xdg.configFile."swayosd/style.css".text = ''
    window {
      background: rgba(25, 23, 36, 0.95);
      border: 1px solid #403d52;
      border-radius: 999px;
      padding: 10px;
    }

    image,
    label {
      color: #e0def4;
    }

    progressbar {
      border-radius: 999px;
      background-color: #26233a;
    }

    progress {
      background-color: #eb6f92;
      border-radius: 999px;
    }
  '';

  # Hypridle
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
    };
  };

  # Wlogout
  programs.wlogout = {
    enable = true;

    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "󰌾  Lock";
        keybind = "l";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "󰜉  Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "󰐥  Shutdown";
        keybind = "s";
      }
    ];

    style = ''
      * {
        background: transparent;
        border: none;
        box-shadow: none;
        outline: none;
      }

      window {
        background-color: rgba(25, 23, 36, 0.92);
        font-family: "JetBrainsMono Nerd Font", monospace;
      }

      button {
        color: #6e6a86;
        font-size: 20px;
        padding: 10px 24px;
        transition: color 150ms ease-in-out;
      }

      button:hover {
        color: #e0def4;
      }

      button:focus {
        color: #eb6f92;
      }
    '';
  };
}
