{
  config,
  lib,
  pkgs,
  repoDir,
  ...
}: let
  inherit (lib.generators) mkLuaInline;

  mod = "SUPER";

  # Hyprland does not expand variables in `env`, so this has to be absolute.
  screenshotsDir = "${config.home.homeDirectory}/Pictures/screenshots";

  # The dispatcher is raw Lua.
  bind = keys: dispatcher: {_args = [keys (mkLuaInline dispatcher)];};
  bindWith = opts: keys: dispatcher: {_args = [keys (mkLuaInline dispatcher) opts];};

  exec = cmd: "hl.dsp.exec_cmd(${builtins.toJSON cmd})";

  # Volume and brightness keys repeat and work while the session is locked.
  bindel = bindWith {
    locked = true;
    repeating = true;
  };
  bindm = bindWith {mouse = true;};

  binde = bindWith {repeating = true;};

  # Grow/shrink focused window; shifted symbols are also bound.
  resizeStep = 60;
  resizeBinds = delta:
    map (keys: binde keys "hl.dsp.window.resize({ x = ${toString delta}, y = ${toString delta}, relative = true })");

  workspaces = lib.range 1 9;

  towards = dispatcher: chord:
    map (d: bind "${chord} + ${d}" ''${dispatcher}({ direction = "${lib.toLower d}" })'') ["LEFT" "RIGHT" "UP" "DOWN"];

  # Omarchy's screenshot bindings. The extra keysyms cover the screenshot key when keyd or
  # its f16 mapping isn't active.
  onPrint = chord: cmd: map (key: bind "${chord}${key}" (exec cmd)) ["Print" "XF86SelectiveScreenshot" "XF86Launch7"];

  # One line of the cheatsheet (home/quickshell/Keys) with the binds behind it, so the sheet
  # lists what is bound and cannot fall behind it. `keyAs` names the keycaps where a line stands
  # for several binds; otherwise they are read off its first bind.
  key = label: binds: {
    inherit label;
    binds = lib.toList binds;
  };
  keyAs = caps: label: binds: key label binds // {inherit caps;};

  # What a key is called on its cap, where that is not Hyprland's name for it.
  capNames = {
    SUPER = "Super";
    SHIFT = "Shift";
    CTRL = "Ctrl";
    ALT = "Alt";
    RETURN = "Enter";
    SPACE = "Space";
    ESCAPE = "Esc";
    Print = "PrtSc";
    EQUAL = "=";
    MINUS = "−";
  };
  capsOf = keys: map (k: capNames.${k} or k) (lib.splitString " + " keys);

  # The sheet's columns, each a list of sections.
  keymap = [
    [
      {
        title = "Windows";
        keys = [
          (key "Close window" (bind "${mod} + W" "hl.dsp.window.close()"))
          (key "Fullscreen" (bind "${mod} + F" "hl.dsp.window.fullscreen()"))
          (key "Float or tile" (bind "${mod} + T" ''hl.dsp.window.float({ action = "toggle" })''))
          (key "Flip the split direction" (bind "${mod} + J" ''hl.dsp.layout("togglesplit")''))
          (keyAs ["Super" "← ↑ ↓ →"] "Move focus" (towards "hl.dsp.focus" mod))
          (keyAs ["Super" "Shift" "← ↑ ↓ →"] "Swap with a neighbour" (towards "hl.dsp.window.swap" "${mod} + SHIFT"))
          (key "Grow window" (resizeBinds resizeStep ["${mod} + EQUAL" "${mod} + SHIFT + PLUS"]))
          (key "Shrink window" (resizeBinds (-resizeStep) ["${mod} + MINUS" "${mod} + SHIFT + UNDERSCORE"]))
          (keyAs ["Super" "Drag"] "Move window" (bindm "${mod} + mouse:272" "hl.dsp.window.drag()"))
          (keyAs ["Super" "Right drag"] "Resize window" (bindm "${mod} + mouse:273" "hl.dsp.window.resize()"))
        ];
      }
    ]
    [
      {
        title = "Apps";
        keys = [
          (key "Launcher" (bind "${mod} + SPACE" (exec "qs ipc call launcher toggle")))
          (key "Terminal" (bind "${mod} + RETURN" (exec "ghostty")))
          (key "Browser" (bind "${mod} + SHIFT + B" (exec "helium")))
          (key "Files" (bind "${mod} + SHIFT + F" (exec "nautilus")))
        ];
      }
      {
        title = "Shell";
        keys = [
          (key "Control Center" (bind "ALT + A" (exec "qs ipc call control toggle")))
          (key "Calendar" (bind "ALT + C" (exec "qs ipc call calendar toggle")))
          (key "Nearby sharing" (bind "ALT + N" (exec "qs ipc call nearby toggle")))
          (key "Power profiles" (bind "ALT + P" (exec "qs ipc call profiles toggle")))
          (key "Theme" (bind "ALT + T" (exec "qs ipc call theme toggle")))
          (key "Wallpaper" (bind "CTRL + ${mod} + SPACE" (exec "qs ipc call wallpaper toggle")))
          (key "Session menu" (bind "${mod} + ESCAPE" (exec "qs ipc call session toggle")))
          (key "Lock" (bind "${mod} + L" (exec "lock-session")))
        ];
      }
    ]
    [
      {
        title = "Workspaces";
        keys = [
          (keyAs ["Super" "1 – 9"] "Go to workspace"
            (map (i: bind "${mod} + ${toString i}" "hl.dsp.focus({ workspace = ${toString i} })") workspaces))
          (keyAs ["Super" "Shift" "1 – 9"] "Send window to workspace"
            (map (i: bind "${mod} + SHIFT + ${toString i}" "hl.dsp.window.move({ workspace = ${toString i} })") workspaces))
        ];
      }
      {
        title = "Capture";
        keys = [
          (key "Screenshot an area" (onPrint "" "grimblast --notify copysave area"))
          (key "Screenshot this display" (onPrint "ALT + " "grimblast --notify copysave output"))
          (key "Screenshot every display" (onPrint "${mod} + CTRL + " "grimblast --notify copysave screen"))
          (key "Pick a colour" (onPrint "${mod} + " "pkill hyprpicker || hyprpicker -a"
            # PrtSc sends Shift+Meta+S, which keyd turns into Print only as a three-key chord.
            # With Super already held its press is too early to join, so SUPER + PrtSc
            # arrives as SUPER + SHIFT + S instead.
            ++ [(bind "${mod} + SHIFT + S" (exec "pkill hyprpicker || hyprpicker -a"))]))
          # Opens the picker, or stops and saves a running recording.
          (key "Record the screen, or stop" (bind "ALT + R" (exec "qs ipc call recorder toggle")))
        ];
      }
      {
        title = "Dictation";
        keys = [
          # Tap to start and stop, or hold to talk. Letting go of SUPER first skips the
          # release, which leaves it recording as if tapped.
          (key "Dictate: tap, or hold to talk" [
            (bind "${mod} + D" (exec "dictate press"))
            (bindWith {release = true;} "${mod} + D" (exec "dictate release"))
          ])
          # The same, cleaned up by a model before it is typed; see home/dictation.nix.
          (key "Dictate, then tidy the text" [
            (bind "${mod} + SHIFT + D" (exec "dictate press --post-process"))
            (bindWith {release = true;} "${mod} + SHIFT + D" (exec "dictate release --post-process"))
          ])
        ];
      }
    ]
  ];

  # Holding AltGr for `after` ms shows the cheatsheet, and letting go hides it. The key stays
  # AltGr: the press is passed on, and a quick AltGr+4 for € is over before the sheet would
  # show. One timer, running only while the key is down, counts the hold and sees the release.
  peekKey = "ISO_Level3_Shift";
  peekKeys =
    bindWith {
      non_consuming = true;
      ignore_mods = true;
    }
    peekKey ''
      (function()
        local tick, after = 40, 320
        local timer, held, shown = nil, 0, false
        local function watch()
          if hl.is_key_down("${peekKey}") then
            held = held + tick
            if not shown and held >= after then
              shown = true
              hl.exec_cmd("qs ipc call keys open")
            end
            return
          end
          timer:set_enabled(false)
          if shown then hl.exec_cmd("qs ipc call keys close") end
          shown = false
        end
        return function()
          held = 0
          if timer then
            timer:set_enabled(true)
          else
            timer = hl.timer(watch, { timeout = tick, type = "repeat" })
          end
        end
      end)()'';

  # With an external monitor connected, workspace 5 lives only there and the
  # rest only on the laptop panel. Rules fix where a workspace is created, so
  # focusing a missing one never opens it on the wrong output.
  pinWorkspaces = ''
    local internal, external
    for _, m in ipairs(hl.get_monitors()) do
      if m.name:match("^eDP") then internal = m.name else external = m.name end
    end
    if internal and external then
      for ws = 1, 9 do
        hl.workspace_rule({ workspace = tostring(ws), monitor = ws == 5 and external or internal })
      end
    end'';

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
    configType = "lua";

    # UWSM owns the user systemd session.
    systemd.enable = false;

    # Loaded ahead of the settings, so plugin options below resolve.
    plugins = [pkgs.dragpile];

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

          # A quiet 1 px edge in two opaque near-ground colours, so the accent is kept for
          # "you are here" (saneAspect's). Rose Pine's; the active theme's are applied over
          # these, see theme.nix.
          border_size = 1;
          col = {
            active_border = "rgba(403d52ff)";
            inactive_border = "rgba(21202eff)";
          };

          resize_on_border = false;
          layout = "dwindle";
        };

        decoration = {
          rounding = 12;
          blur = {
            enabled = true;
            size = 16;
            passes = 3;
            vibrancy = 0.1696;
          };
        };

        animations.enabled = true;

        dwindle = {
          preserve_split = true;
          force_split = 2;
        };

        # XWayland windows render at the monitor's real pixels instead of being stretched from
        # scale 1. Lectern (Chromium, X11-only) passes its own scale; see home/lectern.nix.
        xwayland.force_zero_scaling = true;

        misc = {
          vrr = 0;

          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          # Matches Plymouth's black for the handoff to the lock screen.
          background_color = "rgba(000000ff)";
        };

        # File drags from any client show board 16d's card pile; colours come from the theme
        # (home/theme.nix). The arrow stays during a drag, as on the board.
        plugin.dragpile.cursor = "default";
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

      # Everything on the cheatsheet, then what it leaves out: keys that say what they do.
      bind =
        lib.concatMap (line: line.binds) (lib.concatMap (section: section.keys) (lib.concatLists keymap))
        ++ [
          peekKeys

          (bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
          (bind "XF86AudioPlay" (exec "playerctl play-pause"))
          (bind "XF86AudioNext" (exec "playerctl next"))
          (bind "XF86AudioPrev" (exec "playerctl previous"))

          # A short press locks; logind powers off on a long press (modules/system/session.nix).
          (bind "XF86PowerOff" (exec "lock-session"))

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

        # note's live preview opens beside the editor without taking focus.
        # Chromium names --app windows after their URL, so this is the page
        # note serves at /note-preview.
        {
          match.class = "chrome-127.0.0.1__note-preview-.*";
          no_initial_focus = true;
        }

        # Helix's :preview window, opened on tinymist's page at "/".
        {
          match.class = "chrome-127.0.0.1__-.*";
          no_initial_focus = true;
        }

        {
          match.class = "mpv";
          float = true;
          center = true;
        }

        # Helium's profile picker ("Manage profiles"), which the zen patches
        # give its own class.
        {
          match.class = "^helium-profile-picker$";
          float = true;
          center = true;
        }
      ];

      # Quickshell surfaces animate themselves, so no compositor animation on any of them, by
      # prefix rather than by name: a surface left off a list of names (the phone panel was) is
      # stretched by Hyprland for the length of its layer animation each time it comes out of its
      # parked sliver, a squashed copy of the pill sliding down from the screen edge.
      layer_rule = [
        {
          match.namespace = "quickshell-.*";
          no_anim = true;
        }
      ];

      # Hyprland starts locked (--locked-cmd, modules/system/session.nix), so the helpers can
      # start straight away. Safe mode after a crash skips this config, and with it the helpers.
      on = [
        {
          _args = [
            "hyprland.start"
            (mkLuaInline ''
              function()
                hl.exec_cmd("start-desktop")
              end'')
          ];
        }

        # awww-daemon paints a new output black, and learns of it a moment after
        # Hyprland does, so retry until it accepts the output.
        {
          _args = [
            "monitor.added"
            (mkLuaInline ''
              function(mon)
                ${pinWorkspaces}
                hl.exec_cmd("for _ in $(seq 1 50); do ${pkgs.awww}/bin/awww img -o " .. mon.name
                  .. [[ "$HOME/.local/share/wallpaper/current" && break; sleep 0.1; done]])

                if not mon.name:match("^eDP") then mon:set_workspace({ workspace = "5" }) end
              end'')
          ];
        }

        # mpv sizes its window from the video's pixels and a guessed display scale
        # (2 on the 1.33 laptop panel, 1 if it maps before the output reports
        # one), so a big video could open wider than the screen. Keep its shape
        # but fit it in 65% of the monitor, then re-centre.
        {
          _args = [
            "window.open"
            (mkLuaInline ''
              function(w)
                if w.class ~= "mpv" or not w.floating or not w.monitor then return end
                local m = w.monitor
                local mw, mh = m.size.width / m.scale, m.size.height / m.scale
                if m.transform % 2 == 1 then mw, mh = mh, mw end
                local s = math.min(mw * 0.65 / w.size.x, mh * 0.65 / w.size.y)
                hl.dispatch(hl.dsp.window.resize({ x = math.floor(w.size.x * s), y = math.floor(w.size.y * s), window = w }))
                hl.dispatch(hl.dsp.window.center({ window = w }))
              end'')
          ];
        }

        # A reload drops rules added at runtime.
        {
          _args = [
            "config.reloaded"
            (mkLuaInline "function() ${pinWorkspaces} end")
          ];
        }
      ];
    };
  };

  # mpv's controls scale with window height, and the window.open hook above opens
  # big videos smaller than mpv would; 1.4 gives back the size they had in a 4K
  # video's window. Fullscreen controls are unchanged.
  xdg.configFile."mpv/script-opts/osc.conf".text = "scalewindowed=1.4\n";

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "lock-session";
        # Not loginctl lock-session: logind won't lock greetd's greeter-class session.
        before_sleep_cmd = "lock-session";
        # Hold suspend until Hyprland reports the session locked (auto only does for hyprlock).
        inhibit_sleep = 3;
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })' && qs ipc call clock refresh";
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
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/home/quickshell";

  # The launcher's emoji table, generated from nixpkgs' Unicode data. The config above is
  # out of store, so it reads this from a fixed path; see Services/EmojiSearch.qml.
  xdg.dataFile."quickshell/emoji.tsv".source = "${pkgs.quickshell-emoji}/share/quickshell/emoji.tsv";

  # The cheatsheet's lines, from the binds above; see Services/Keymap.qml.
  xdg.dataFile."quickshell/keys.json".text = builtins.toJSON {
    columns =
      map (map (section: {
        inherit (section) title;
        rows =
          map (line: {
            inherit (line) label;
            caps = line.caps or (capsOf (lib.head (lib.head line.binds)._args));
          })
          section.keys;
      }))
      keymap;
  };

  # The account picture, read by the lock screen. Out of store, so replacing
  # profile.jpg in this repo shows on the next lock without a rebuild.
  home.file.".face" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/profile.jpg";
    force = true;
  };
}
