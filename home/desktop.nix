{ config, pkgs, hyprland, ... }:
{
  # Hyprland config
  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;

    # Prevent conflict with UWSM and systemd
    systemd.enable = false;

    settings = {
      # Monitor - auto-detect
      monitor = ",preferred,auto,1.60";

      # Autostart
      exec-once = [
        "awww-daemon"
        "awww img ~/Pictures/wallpaper.jpg"
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

        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        resize_on_border = false;
        layout = "dwindle";
      };

      # Decoration
      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
          vibrancy = 0.1696;
        };
        shadow = {
          enabled = true;
          range = 8;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };

      # Animations
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 5, myBezier"
          "windowsOut, 1, 5, default, popin 80%"
          "border, 1, 8, default"
          "borderangle, 1, 8, default"
          "fade, 1, 5, default"
          "workspaces, 1, 5, default"
        ];
      };

      # Layouts
      dwindle = {
        preserve_split = true;
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
        "$mod, ESCAPE, exec, wlogout"

        # Clipboard history
        # "$mod, C, cliphist list | fzf | cliphist decode | wl-copy"

        # Laucher
        "$mod, SPACE, exec, vicinae toggle"

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
      ];
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
        margin-top =  6;

        modules-left = [ "custom/user" "clock" "mpris" ];
        modules-center = [ "hyprland/workspaces" ];
        modules-right = [ "group/tray-expander" "bluetooth" "network" "pulseaudio" "cpu" "battery" ];

        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{icon}";
          format-icons = {
            default = "";
            active = "";
            urgent = "";
          };
          persistent-workspaces = {
            "*" = [ 1 2 3 4 5 ];
          };
          all-outputs = true;
          sort-by-number = true;
        };

        mpris = {
          format = "{player_icon} {dynamic}";
          format-paused = "{status_icon} <i>{dynamic}</i>";
          format-stopped = "";
          player-icons = {
            default = "a";
            mpv = "b";
          };
          status-icons = {
            paused = "p";
          };
          ignored-players = [
            "blanket"
            "Blanket"
            "com.rafaelmardojai.Blanket"
          ];
          max-length = 40;
        };

        "custom/user" = {
          exec = "whoami";
          format = "{}";
          interval = "once";
          tooltip = false;
        };

        cpu = {
          interval = 5;
          format = "d";
          on-click = "btop";
        };

        clock = {
          format = "\uf4ab {:L%d %B %Y %H:%M}";
          tooltip = false;
        };

        network = {
          format-icons = [ "a" "b" "c" "d" "e" ];
          format = "{icon}  {essid}";
          format-wifi = "{icon}  {essid}";
          format-ethernet = "a";
          format-disconnected = "b";
          tooltip-format-wifi = "{essid} ({frequency} GHz)";
          tooltip-format-ethernet = "Connected";
          tooltip-format-disconnected = "Disconnected";
          interval = 3;
          spacing = 1;
          on-click = "netpala";
        };

        battery = {
          format = "{capacity}% {icon}";
          format-discharging = "{capacity}% {icon}";
          format-charging = "{icon}";
          format-plugged = "";
          format-icons = {
            charging = [
              "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
            ];
            default = [
              "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
            ];
          };
          format-full = "a";
          tooltip-format-discharging = "{power:>1.0f}Wd {capacity}%";
          tooltip-format-charging = "{power:>1.0f}Wu {capacity}%";
          interval = 5;
          states = {
            warning = 20;
            critical = 10;
          };
        };

        bluetooth = {
          format = "";
          format-disabled = "a";
          format-off = "b";
          format-connected = "c";
          format-no-controller = "d";
          tooltip-format = "Devices connected: {num_connections}";
          on-click = "bluetui";
        };

        pulseaudio = {
          format = "{icon}";
          on-click = "wiremix";
          tooltip-format = "Playing at {volume}%";
          scroll-step = 5;
          format-muted = "";
          format-icons = {
            headphone = "";
            default = [ "" "" "" ];
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
          format = "";
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
          margin-right: 8px;
          padding: 0 4.25px;
          background: #0f0f0f;
        }

        #workspaces {
          padding: 5px 4px;
          border-radius: 18px;
          background: #0f0f0f;
        }

        #workspaces button {
          padding: 0 4px;
          margin: 0 3px;
          min-width: 12px;
          border-radius: 16px;
          background-color: #e7bdb7;
          transition: all 150ms ease-in-out;
        }

        #workspaces button.active {
          background-color: #561e18;
          min-width: 30px;
          transition: all 150ms ease-in-out;
        }

        #cpu,
        #battery,
        #pulseaudio {
          min-width: 12px;
          margin: 0 7.5px;
        }

        #tray {
          margin-right: 16px;
        }

        #bluetooth {
          margin-right: 17px;
        }

        #network {
          margin-right: 4px;
        }

        #network.disconnected {
          margin-right: 10px;
        }

        #custom-expand-icon {
          margin-right: 18px;
          margin-left: 5px;
        }

        tooltip {
          border-radius: 8px;
          padding: 2px;
          background: #0f0f0f;
        }

        #tray menu {
          border-radius: 8px;
          padding: 2px;
          background: #0f0f0f;
        }

        #mpris:not(.stopped) {
          margin-left: 7.5px;
        }

        .hidden {
          opacity: 0;
        }

        #custom-user {
          padding-right: 12px;
          border-top-right-radius: 999px;
          border-bottom-right-radius: 999px;
          margin-right: 7.5px;
          background: #0f0f0f;
        }

        #clock {
          padding: 0 12px;
          border-radius: 999px;
          background: #0f0f0f;
        }

        #mpris {
          border-radius: 999px;
        }

        #mpris.playing,
        #mpris.paused {
          padding: 0 12px;
          background: #0f0f0f;
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

      background = [{
        monitor = "";
        color = "rgba(24,24,36,1.0)";
        path = "~/background";
        blur_passes = 3;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0;
      }];

      animations = [{
        enabled = true;
      }];

      label = [
        {
          monitor = "";
          text = ''cmd[update:1000] echo -e "$(date + "%A, %B, %d")"'';
          color = "rgba(205,214,244,1.0)";
          font_size = 25;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 250";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:1000] echo -e "<span>$(date + "%H:%M")</span>"'';
          color = "rgba(205,214,244,1.0)";
          font_size = 150;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 135";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:1000] echo -e "$(playerctl metadata --format "{{title} d {{artist}}")"'';
          color = "rgba(205,214,244,1.0)";
          font_size = 18;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 50";
          halign = "center";
          valign = "bottom";
        } 
      ];

      input-field = [{
        monitor = "";
        size = "400, 100";
        position = "0, -80";
        halign = "center";
        valign = "center";

        inner_color = "rgba(24,24,36,0.8)";
        outer_color = "rgba(205,214,244,1.0)";
        outline_thickness = 2;
        
        font_family = "JetBrainsMono Nerd Font";
        font_color = "rgba(205,214,244,1.0)";

        placeholder_text = "<span> Enter Password b </span>";
        check_color = "rgba(68,157,171,1.0)";
        fail_text = "<i>$FAIL ($ATTEMPTS)</i>";
        dots_spacing = 0.3;
        dots_size = 0.2;

        shadow_passes = 0;
        fade_on_empty = false;
      }];

      auth."fingerprint:enabled" = true;
    };
  };

  # Mako - notification daemon
  services.mako = {
    enable = true;
    backgroundColor = "#0f0f0f";
    textColor = "#cdd6f4";
    borderColor = "#1F282F";
    padding = "20, 16";
    borderSize = 1;
    borderRadius = 4;

    anchor = "top-right";
    defaultTimeout = 5000;
    width = 420;
    maxIconSize = 32;
    font = "JetBrainsMono Nerd Font";
  };

  # Hypridle
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprland || hyprlock";
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
      }    

      window {
        background-color: rgba(30,30,46,0.9);
      }

      button {
        color: #cdd6f4;
        background-color: rgba(49,50,68,0.8);
        border: 2px solid #313244;
        border-radius: 8px;
        margin: 8px;
        font-size: 14px;
        transition: all 0.2s ease;
      }

      button:hover {
        background-color: rgba(137,180,250,0.5);
        border-color: #89b4fa;
        color: #89b4fa;
      }

      #lock { background-image: url("icons/lock.png"); }
      #logout { background-image: url("icons/logout.png"); }
      #reboot { background-image: url("icons/reboot.png"); }
      #shutdown { background-image: url("icons/shutdown.png"); }
    '';
  };

  services.vicinae = {
    enable = true;

    settings = {
      hotkey = "";
      closeOnFocusLoss = true;
      showInTaskbar = false;

      theme = "catppuccin-mocha";

      defaultCommand = "applications";
    };
  };
}
