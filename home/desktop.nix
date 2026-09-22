{
  config,
  lib,
  pkgs,
  hyprland,
  ...
}: let
  inherit (lib.generators) mkLuaInline;

  mod = "SUPER";

  # Hyprland does not expand variables in `env`, so this has to be absolute.
  screenshotsDir = "${config.home.homeDirectory}/Pictures/screenshots";

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

  # Grow/shrink the focused window; shifted symbols are bound too.
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
  # grimblast writes into XDG_SCREENSHOTS_DIR and will not create it itself.
  home.file."Pictures/screenshots/.keep".text = "";

  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    configType = "lua";

    # UWSM owns the user systemd session.
    systemd.enable = false;

    settings = {
      env = [
        {_args = ["XCURSOR_SIZE" "24"];}
        {_args = ["XCURSOR_THEME" "Bibata-Modern-Classic"];}
        {_args = ["HYPRCURSOR_SIZE" "24"];}
        {_args = ["NIXOS_OZONE_WL" "1"];}
        {_args = ["XDG_SCREENSHOTS_DIR" screenshotsDir];}
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

          # Rose Pine's. The active theme's are applied over these; see theme.nix.
          col = {
            active_border = "rgba(524f67aa)";
            inactive_border = "rgba(26233aaa)";
          };

          resize_on_border = false;
          layout = "dwindle";
        };

        decoration = {
          rounding = 8;
          blur = {
            enabled = true;
            size = 16;
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
          vrr = 0;

          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          # Matches Plymouth's black for the handoff to the lock screen.
          background_color = "rgba(000000ff)";
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
        ++ lib.concatMap (key: [
          # Omarchy screenshot bindings. The extra keysyms cover the screenshot
          # key when keyd or its f16 mapping isn't active.
          (bind key (exec "grimblast --notify copysave area"))
          (bind "ALT + ${key}" (exec "grimblast --notify copysave output"))
          (bind "${mod} + ${key}" (exec "pkill hyprpicker || hyprpicker -a"))
          (bind "${mod} + CTRL + ${key}" (exec "grimblast --notify copysave screen"))
        ]) ["Print" "XF86SelectiveScreenshot" "XF86Launch7"]
        ++ [
          (bind "${mod} + L" (exec "lock-session"))

          (bind "${mod} + ESCAPE" (exec "qs ipc call session toggle"))

          (bind "${mod} + SPACE" (exec "qs ipc call launcher toggle"))

          (bind "ALT + A" (exec "qs ipc call control toggle"))

          (bind "CTRL + ${mod} + SPACE" (exec "qs ipc call wallpaper toggle"))

          (bind "ALT + T" (exec "qs ipc call theme toggle"))

          # Opens the picker, or stops and saves a running recording.
          (bind "ALT + R" (exec "qs ipc call recorder toggle"))

          (bind "ALT + C" (exec "qs ipc call calendar toggle"))

          (bind "ALT + P" (exec "qs ipc call profiles toggle"))

          (bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
          (bind "XF86AudioPlay" (exec "playerctl play-pause"))
          (bind "XF86AudioNext" (exec "playerctl next"))
          (bind "XF86AudioPrev" (exec "playerctl previous"))

          (bindm "${mod} + mouse:272" "hl.dsp.window.drag()")
          (bindm "${mod} + mouse:273" "hl.dsp.window.resize()")

          # Routed through Quickshell so the OSD shows even at the limits.
          (bindel "XF86AudioRaiseVolume" (exec "qs ipc call volume up"))
          (bindel "XF86AudioLowerVolume" (exec "qs ipc call volume down"))
          (bindel "XF86MonBrightnessUp" (exec "qs ipc call brightness up"))
          (bindel "XF86MonBrightnessDown" (exec "qs ipc call brightness down"))
        ];

      window_rule = [
        # Ignore client maximize requests; Electron's restored maximize state
        # otherwise draws a tiled window over its neighbours.
        {
          match.class = ".*";
          suppress_event = "maximize";
        }

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

      # Quickshell panels animate themselves, so no compositor fade.
      layer_rule = [
        {
          match.namespace = "quickshell-(bar|launcher|control|wallpaper|theme|recorder|calendar|session|profiles|notifications|osd|panel)";
          no_anim = true;
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

  # The colours are included from the active theme; see theme.nix.
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

  # Driven by the shell's night light tile; starts at identity.
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "hyprsunset colour temperature daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset --identity";
      Restart = "always";
      RestartSec = 1;
    };

    Install.WantedBy = ["graphical-session.target"];
  };

  # Out-of-store symlink enables QML hot reload without rebuilding.
  programs.quickshell.enable = true;

  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/quickshell";
}
