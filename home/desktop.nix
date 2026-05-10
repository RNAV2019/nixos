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
      # Monitor - auto-detect
      monitor = ",preferred,auto,1.60";

      # Autostart
      exec-once = [
        "hyprlock"
        "awww-daemon"
        "awww img ~/Pictures/backgrounds/ching-yeh.png"
        "waybar"
        "mako"
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

        "col.active_border" = "rgba(444444ff) rgba(333333ff) 45deg";
        "col.inactive_border" = "rgba(1e1e1eaa)";

        resize_on_border = false;
        layout = "dwindle";
      };

      # Decoration
      decoration = {
        rounding = 10;
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
          "windows, 1, 3.79, easeOutQuint"
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
          "specialWorkspace, 1, 3, easeOutQuint, slidevert"
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
        ", Print, exec, grimblast copy area"
        "SHIFT, Print, exec, grimblast copy screen"

        # Lock screen
        "$mod, L, exec, hyprlock"

        # Logout menu
        "$mod, ESCAPE, exec, pkill wlogout || wlogout"

        # Clipboard history
        # "$mod, C, cliphist list | fzf | cliphist decode | wl-copy"

        # Launcher (toggle)
        "$mod, SPACE, exec, pkill fuzzel || fuzzel"

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

        "match:class bluetui-popup, float on"
        "match:class bluetui-popup, center on"
        "match:class bluetui-popup, size 900 600"

        "match:class btop-popup, float on"
        "match:class btop-popup, center on"
        "match:class btop-popup, size 900 600"

        "match:class wlctl-popup, float on"
        "match:class wlctl-popup, center on"
        "match:class wlctl-popup, size 900 600"

        "match:class wiremix-popup, float on"
        "match:class wiremix-popup, center on"
        "match:class wiremix-popup, size 900 600"
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
        outer-pad = 8;
        placeholder = "Launch or calculate...";
      };
      colors = {
        background = "0d0d0ddd";
        text = "c8c8c8ff";
        match = "cc3333ff";
        selection = "2a2a2aff";
        selection-text = "c8c8c8ff";
        selection-match = "cc3333ff";
        border = "2a2a2aff";
      };
      border = {
        width = 1;
        radius = 8;
      };
      icons = {
        enabled = false;
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
          format-paused = "⏸ <i>{dynamic}</i>";
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
        };

        cpu = {
          interval = 5;
          format = "󰍛";
          on-click = "ghostty --class=btop-popup -e btop";
        };

        clock = {
          format = "  {:L%d %B %Y  %H:%M}";
          tooltip = false;
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
          on-click = "ghostty --class=wlctl-popup -e wlctl";
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
          on-click = "ghostty --class=bluetui-popup -e bluetui";
        };

        pulseaudio = {
          format = "{icon}";
          on-click = "ghostty --class=wiremix-popup -e wiremix";
          tooltip-format = "Playing at {volume}%";
          scroll-step = 5;
          format-muted = "";
          format-icons = {
            headphone = "";
            default = ["" "" ""];
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
        color: #c8c8c8;
      }

      .modules-left {
        border-radius: 999px;
        margin-left: 4px;
      }

      .modules-center {
        border-radius: 999px;
      }

      .modules-right {
        border-radius: 999px;
        margin-right: 9px;
        padding: 0 8px;
        background: #0d0d0d;
      }

      #workspaces {
        padding: 5px 4px;
        border-radius: 18px;
        background: #0d0d0d;
      }

      #workspaces button {
        padding: 0 4px;
        margin: 0 3px;
        min-width: 12px;
        border-radius: 16px;
        background-color: #2a2a2a;
        color: #666666;
        transition: all 150ms ease-in-out;
      }

      #workspaces button.active {
        background-color: #cc3333;
        color: #0d0d0d;
        min-width: 28px;
        border-radius: 999px;
        transition: all 150ms ease-in-out;
      }

      #workspaces button:hover {
        background-color: #3a3a3a;
        color: #c8c8c8;
      }

      #cpu,
      #battery,
      #pulseaudio,
      #network,
      #bluetooth {
        margin: 0 6px;
      }

      #tray {
        margin-right: 10px;
      }

      #custom-expand-icon {
        margin-right: 14px;
        margin-left: 4px;
      }

      tooltip {
        border-radius: 8px;
        padding: 4px;
        background: #0d0d0d;
        border: 1px solid #2a2a2a;
      }

      #tray menu {
        border-radius: 8px;
        padding: 2px;
        background: #0d0d0d;
      }

      #mpris:not(.stopped) {
        margin-left: 7.5px;
      }

      .hidden {
        opacity: 0;
      }

      #custom-nix {
        padding: 5px 7px;
        border-radius: 50%;
        background: #0d0d0d;
        color: #cc3333;
        font-size: 15px;
        margin-left: 8px;
        margin-right: 7.5px;
        min-width: 15px;
      }

      #clock {
        padding: 0 14px;
        border-radius: 999px;
        background: #0d0d0d;
        margin-right: 7.5px;
      }

      #mpris {
        border-radius: 999px;
      }

      #mpris.playing,
      #mpris.paused {
        padding: 0 12px;
        background: #0d0d0d;
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
        grace = 0;
      };

      background = [
        {
          monitor = "";
          color = "rgba(13,13,13,1.0)";
          path = "~/Pictures/backgrounds/ching-yeh.png";
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
          color = "rgba(200,200,200,1.0)";
          font_size = 25;
          font_family = "Inter Bold";
          position = "0, 250";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:1000] echo -e "<span>$(date +"%H:%M")</span>"'';
          color = "rgba(200,200,200,1.0)";
          font_size = 150;
          font_family = "Inter Bold";
          position = "0, 135";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:1000] echo -e "$(playerctl metadata --format '{{title}} - {{artist}}')"'';
          color = "rgba(140,140,140,1.0)";
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

          inner_color = "rgba(13,13,13,0.8)";
          outer_color = "rgba(204,51,51,1.0)";
          outline_thickness = 2;

          font_family = "Inter Bold";
          font_color = "rgba(200,200,200,1.0)";

          placeholder_text = "<span> Enter Password </span>";
          check_color = "rgba(150,150,150,1.0)";
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
      background-color = "#0d0d0d";
      text-color = "#c8c8c8";
      border-color = "#2a2a2a";
      padding = "20,16";
      border-size = 1;
      border-radius = 4;
      anchor = "top-right";
      default-timeout = 5000;
      width = 420;
      max-icon-size = 32;
      font = "JetBrainsMono Nerd Font";
    };
  };

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
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "uwsm stop";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
    ];

    style = ''
      * {
        background-image: none;
        font-family: "JetBrainsMono Nerd Font";
        color: #c8c8c8;
      }

      window {
        background-color: rgba(13,13,13,0.9);
      }

      button {
        background-color: rgba(20,20,20,0.8);
        border: 2px solid #2a2a2a;
        border-radius: 8px;
        margin: 8px;
        font-size: 14px;
        transition: all 0.2s ease;
      }

      button:hover {
        background-color: rgba(204,51,51,0.15);
        border-color: #cc3333;
        color: #cc3333;
      }

      #lock { background-image: url("icons/lock.png"); }
      #logout { background-image: url("icons/logout.png"); }
      #reboot { background-image: url("icons/reboot.png"); }
      #shutdown { background-image: url("icons/shutdown.png"); }
    '';
  };
}
