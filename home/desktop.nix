{
  config,
  lib,
  pkgs,
  hyprland,
  ...
}: let
  inherit (lib.generators) mkLuaInline;

  mod = "SUPER";

  # `hl.bind(keys, dispatcher[, opts])`. The dispatcher is raw Lua.
  bind = keys: dispatcher: {_args = [keys (mkLuaInline dispatcher)];};
  bindWith = opts: keys: dispatcher: {_args = [keys (mkLuaInline dispatcher) opts];};

  exec = cmd: "hl.dsp.exec_cmd(${builtins.toJSON cmd})";

  # Volume and brightness keys repeat and work while the session is locked.
  bindel = bindWith {
    locked = true;
    repeating = true;
  };
  bindm = bindWith {mouse = true;};

  # Window resize keys repeat while held.
  binde = bindWith {repeating = true;};

  # Grow/shrink the focused window. On a US layout `SUPER + "+"` reaches the
  # compositor as SUPER + SHIFT + plus, so bind the shifted symbols too.
  resizeStep = 60;
  resizeBinds = delta:
    map (keys: binde keys "hl.dsp.window.resize({ x = ${toString delta}, y = ${toString delta}, relative = true })");

  workspaces = lib.range 1 9;

  # Rose Pine floating overlays share the same shape.
  floatingOverlay = class: {
    match.class = class;
    float = true;
    center = true;
    border_size = 0;
    rounding = 18;
  };
in {
  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    configType = "lua";

    # UWSM owns the user systemd session.
    systemd.enable = false;

    settings = {
      monitor = [
        # 1920x1200 across 300 mm is 163 DPI, which sits right where a fractional
        # scale is tempting. Resist it: Xwayland and any client without
        # wp-fractional-scale-v1 render at the next integer scale and get
        # resampled, and that blur costs more than the size gains. Scale 1 is
        # pixel-exact; grow font sizes instead.
        {
          output = "eDP-1";
          mode = "preferred";
          position = "0x0";
          scale = 1.0;
        }
      ];

      env = [
        {_args = ["XCURSOR_SIZE" "24"];}
        {_args = ["XCURSOR_THEME" "Bibata-Modern-Classic"];}
        {_args = ["HYPRCURSOR_SIZE" "24"];}
        {_args = ["NIXOS_OZONE_WL" "1"];}
        {_args = ["XDG_SCREENSHOTS_DIR" "$HOME/Pictures/screenshots"];}
        {
          _args = [
            "LD_LIBRARY_PATH"
            (lib.makeLibraryPath [pkgs.wayland pkgs.libxkbcommon pkgs.vulkan-loader])
          ];
        }
      ];

      config = {
        input = {
          kb_layout = "gb";
          follow_mouse = 1;
          mouse_refocus = false;
          touchpad = {
            natural_scroll = false;
            tap_to_click = true;
            scroll_factor = 0.5;
          };
          sensitivity = 0;
        };

        general = {
          gaps_in = 5;
          gaps_out = 10;

          border_size = 2;

          col = {
            active_border = "rgba(524f67aa)";
            inactive_border = "rgba(26233aaa)";
          };

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

        animations.enabled = true;

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
      };

      # Omarchy preset.
      curve = [
        {
          _args = [
            "easeOutQuint"
            {
              type = "bezier";
              points = [[0.23 1] [0.32 1]];
            }
          ];
        }
        {
          _args = [
            "easeInOutCubic"
            {
              type = "bezier";
              points = [[0.65 0.05] [0.36 1]];
            }
          ];
        }
        {
          _args = [
            "linear"
            {
              type = "bezier";
              points = [[0 0] [1 1]];
            }
          ];
        }
        {
          _args = [
            "almostLinear"
            {
              type = "bezier";
              points = [[0.5 0.5] [0.75 1.0]];
            }
          ];
        }
        {
          _args = [
            "quick"
            {
              type = "bezier";
              points = [[0.15 0] [0.1 1]];
            }
          ];
        }
      ];

      animation = [
        {
          leaf = "global";
          enabled = true;
          speed = 10;
          bezier = "default";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 5.39;
          bezier = "easeOutQuint";
        }
        {
          leaf = "windows";
          enabled = true;
          speed = 4.79;
          bezier = "easeOutQuint";
        }
        {
          leaf = "windowsIn";
          enabled = true;
          speed = 4.1;
          bezier = "easeOutQuint";
          style = "popin 87%";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 1.49;
          bezier = "linear";
          style = "popin 87%";
        }
        {
          leaf = "fadeIn";
          enabled = true;
          speed = 1.73;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeOut";
          enabled = true;
          speed = 1.46;
          bezier = "almostLinear";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 3.03;
          bezier = "quick";
        }
        {
          leaf = "layers";
          enabled = true;
          speed = 3.81;
          bezier = "easeOutQuint";
        }
        {
          leaf = "layersIn";
          enabled = true;
          speed = 4;
          bezier = "easeOutQuint";
          style = "fade";
        }
        {
          leaf = "layersOut";
          enabled = true;
          speed = 1.5;
          bezier = "linear";
          style = "fade";
        }
        {
          leaf = "fadeLayersIn";
          enabled = true;
          speed = 1.79;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeLayersOut";
          enabled = true;
          speed = 1.39;
          bezier = "almostLinear";
        }
        {
          leaf = "workspaces";
          enabled = false;
          speed = 1;
          bezier = "default";
        }
        {
          leaf = "workspacesIn";
          enabled = false;
          speed = 1;
          bezier = "default";
        }
        {
          leaf = "workspacesOut";
          enabled = false;
          speed = 1;
          bezier = "default";
        }
      ];

      bind =
        [
          (bind "${mod} + RETURN" (exec "ghostty"))
          (bind "${mod} + SHIFT + B" (exec "helium"))
          (bind "${mod} + SHIFT + F" (exec "nautilus"))
          (bind "${mod} + P" (exec "project-picker --toggle"))

          (bind "${mod} + W" "hl.dsp.window.close()")
          (bind "${mod} + T" ''hl.dsp.window.float({ action = "toggle" })'')
          (bind "${mod} + J" ''hl.dsp.layout("togglesplit")'')
          (bind "${mod} + F" "hl.dsp.window.fullscreen()")
        ]
        ++ resizeBinds resizeStep ["${mod} + EQUAL" "${mod} + SHIFT + PLUS"]
        ++ resizeBinds (-resizeStep) ["${mod} + MINUS" "${mod} + SHIFT + UNDERSCORE"]
        ++ [
          (bind "${mod} + LEFT" ''hl.dsp.focus({ direction = "left" })'')
          (bind "${mod} + RIGHT" ''hl.dsp.focus({ direction = "right" })'')
          (bind "${mod} + UP" ''hl.dsp.focus({ direction = "up" })'')
          (bind "${mod} + DOWN" ''hl.dsp.focus({ direction = "down" })'')

          (bind "${mod} + SHIFT + LEFT" ''hl.dsp.window.swap({ direction = "left" })'')
          (bind "${mod} + SHIFT + RIGHT" ''hl.dsp.window.swap({ direction = "right" })'')
          (bind "${mod} + SHIFT + UP" ''hl.dsp.window.swap({ direction = "up" })'')
          (bind "${mod} + SHIFT + DOWN" ''hl.dsp.window.swap({ direction = "down" })'')
        ]
        ++ map (i: bind "${mod} + ${toString i}" "hl.dsp.focus({ workspace = ${toString i} })") workspaces
        ++ map (i: bind "${mod} + SHIFT + ${toString i}" "hl.dsp.window.move({ workspace = ${toString i} })") workspaces
        ++ [
          # Match Omarchy screenshot bindings.
          (bind "Print" (exec "grimblast --notify copysave area"))
          (bind "ALT + Print" (exec "grimblast --notify copysave output"))
          (bind "${mod} + Print" (exec "pkill hyprpicker || hyprpicker -a"))
          (bind "${mod} + CTRL + Print" (exec "grimblast --notify copysave screen"))

          (bind "${mod} + L" (exec "lock-session"))

          (bind "${mod} + ESCAPE" (exec "qs ipc call session toggle"))

          # Match bar panel shortcuts.
          (bind "${mod} + CTRL + A" (exec "qs ipc call panels toggle audio"))
          (bind "${mod} + CTRL + W" (exec "qs ipc call panels toggle network"))
          (bind "${mod} + CTRL + B" (exec "qs ipc call panels toggle bluetooth"))
          (bind "${mod} + CTRL + P" (exec "qs ipc call panels toggle battery"))
          (bind "${mod} + CTRL + S" (exec "qs ipc call panels toggle system"))
          (bind "${mod} + CTRL + C" (exec "qs ipc call panels toggle clock"))

          (bind "${mod} + SPACE" (exec "mycelium --toggle"))

          (bind "CTRL + ${mod} + SPACE" (exec "cherry --toggle"))

          (bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
          (bind "XF86AudioPlay" (exec "playerctl play-pause"))
          (bind "XF86AudioNext" (exec "playerctl next"))
          (bind "XF86AudioPrev" (exec "playerctl previous"))

          (bindm "${mod} + mouse:272" "hl.dsp.window.drag()")
          (bindm "${mod} + mouse:273" "hl.dsp.window.resize()")

          # Quickshell performs these and renders the OSD, so a press at either
          # rail still shows feedback.
          (bindel "XF86AudioRaiseVolume" (exec "qs ipc call volume up"))
          (bindel "XF86AudioLowerVolume" (exec "qs ipc call volume down"))
          (bindel "XF86MonBrightnessUp" (exec "qs ipc call brightness up"))
          (bindel "XF86MonBrightnessDown" (exec "qs ipc call brightness down"))
        ];

      window_rule = [
        # Electron restores a saved maximized state on launch, which leaves the
        # window tiled in the dwindle tree but drawn over the whole workspace on
        # top of its neighbours. A tiled layout has no use for client-requested
        # maximize, so drop the request for everything.
        {
          match.class = ".*";
          suppress_event = "maximize";
        }

        (floatingOverlay "uk.co.ryannavsaria.project-picker")
        (floatingOverlay "uk.co.ryannavsaria.mycelium")
        (floatingOverlay "uk.co.ryannavsaria.cherry")

        {
          match.class = "org.pwmt.zathura";
          no_initial_focus = true;
        }

        {
          match.class = "mpv";
          float = true;
          center = true;
        }
      ];

      # Bar panels are opaque xdg popups; only the session layer needs blur.
      layer_rule = [
        {
          match.namespace = "quickshell-session";
          blur = true;
        }
      ];

      # Block bindings and helpers until Quickshell secures every output.
      on = {
        _args = [
          "hyprland.start"
          (mkLuaInline ''
            function()
              hl.dispatch(hl.dsp.submap("lockdown"))
              hl.exec_cmd("start-desktop")
            end'')
        ];
      };
    };

    # The catchall registers lockdown and blocks normal startup bindings.
    submaps.lockdown.settings.bind = [
      (bind "catchall" "hl.dsp.no_op()")
    ];
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
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
      };
    };
  };

  # Out-of-store symlink enables QML hot reload without rebuilding.
  programs.quickshell.enable = true;

  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/quickshell";
}
