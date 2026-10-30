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

  gapsOut = 10;

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

  # Super+scroll zooms the screen by a fixed ratio per notch (dir is 1 in, -1 out), clamped
  # to 1x-4x. Snapping near 1x lets a few notches out land exactly on it. Set at runtime
  # like this, the zoom reverts on a config reload; zoomFactor animates the change.
  zoomRatio = 1.25;
  zoomMax = 4.0;
  zoomBy = dir: ''
    function()
      qs_super_used()
      local z = hl.get_config("cursor.zoom_factor") * ${toString zoomRatio} ^ ${toString dir}
      if z < 1.05 then z = 1 end
      hl.config({ cursor = { zoom_factor = math.min(z, ${toString zoomMax}) } })
    end'';

  floatingOverlay = class: {
    match.class = class;
    float = true;
    center = true;
    border_size = 0;
    rounding = 18;
  };

  keybinds = import ./keybinds.nix {inherit lib;};

  # The cheatsheet shows while Super is held on its own. Hyprland decides, not the shell: it
  # sees every key (a shell surface only sees those sent to it), and a bind pair on Super
  # cannot tell a lone hold from the start of a combo. The key event fires before Hyprland
  # updates its pressed-key set, so a Super press arms a timer only when no other key is
  # down, any other key press disarms it, and when it fires Super must still be the only key
  # held. Releasing Super hides the sheet. Keycodes are xkb's (evdev + 8): Super_L, Super_R.
  # Mouse and scroll Super binds call qs_super_used() themselves, as they are not key events.
  # Each call to the shell carries the config's start time and a counter, so a hide that
  # overtakes a show (they are two processes) is not undone by the late show; see Bus.qml.
  cheatHoldMs = 600;
  superHold = ''
    do
      local SUPER_L, SUPER_R = 133, 134
      local epoch, timer, seq, shown = os.time(), nil, 0, false

      local function others_down()
        for code = 9, 255 do
          if code ~= SUPER_L and code ~= SUPER_R and hl.is_key_down(code) then return true end
        end
        return false
      end

      local function disarm()
        if timer then timer:set_enabled(false); timer = nil end
      end

      local function call(verb)
        seq = seq + 1
        hl.exec_cmd("qs ipc call cheatsheet " .. verb .. " " .. epoch .. " " .. seq)
      end

      function qs_super_used() disarm() end

      hl.on("input.keyboard.key", function(code, _, state)
        if code == SUPER_L or code == SUPER_R then
          if state == 1 then
            if not others_down() then
              disarm()
              timer = hl.timer(function()
                timer = nil
                if (hl.is_key_down(SUPER_L) or hl.is_key_down(SUPER_R)) and not others_down() then
                  shown = true
                  call("hold")
                end
              end, { timeout = ${toString cheatHoldMs}, type = "oneshot" })
            end
          elseif state == 0 then
            disarm()
            if shown then shown = false; call("release") end
          end
        elseif state == 1 then
          -- A combo has begun: whatever the sheet was for is over, so it goes too.
          disarm()
          if shown then shown = false; call("release") end
        end
      end)
    end'';

  # What every key does. The binds, the touchpad gestures and the cheatsheet shown while
  # Super is held all come from these rows; see home/keybinds.nix for the shape. Rows are
  # listed in the order the sheet draws them within a group.
  row = group: desc: binds: {inherit group desc binds;};
  rowKeys = group: desc: keys: binds: {inherit group desc keys binds;};

  # The three keysyms the screenshot key can arrive as. The extra ones cover it when keyd or
  # its f16 mapping isn't active (Omarchy's bindings).
  printKeys = ["Print" "XF86SelectiveScreenshot" "XF86Launch7"];
  onPrint = prefix: dispatcher: map (key: bind "${prefix}${key}" dispatcher) printKeys;

  keyRows = [
    (row "Apps" "Terminal" [(bind "${mod} + RETURN" (exec "ghostty"))])
    (row "Apps" "Browser" [(bind "${mod} + SHIFT + B" (exec "helium"))])
    (row "Apps" "Files" [(bind "${mod} + SHIFT + F" (exec "nautilus"))])

    (row "Windows" "Close" [(bind "${mod} + W" "hl.dsp.window.close()")])
    (row "Windows" "Float" [(bind "${mod} + T" ''hl.dsp.window.float({ action = "toggle" })'')])
    (row "Windows" "Toggle split" [(bind "${mod} + J" ''hl.dsp.layout("togglesplit")'')])
    (row "Windows" "Fullscreen" [(bind "${mod} + F" "hl.dsp.window.fullscreen()")])
    (rowKeys "Windows" "Focus" ["Super" "←" "→" "↑" "↓"] [
      (bind "${mod} + LEFT" ''hl.dsp.focus({ direction = "left" })'')
      (bind "${mod} + RIGHT" ''hl.dsp.focus({ direction = "right" })'')
      (bind "${mod} + UP" ''hl.dsp.focus({ direction = "up" })'')
      (bind "${mod} + DOWN" ''hl.dsp.focus({ direction = "down" })'')
    ])
    (rowKeys "Windows" "Swap" ["Super" "Shift" "←" "→" "↑" "↓"] [
      (bind "${mod} + SHIFT + LEFT" ''hl.dsp.window.swap({ direction = "left" })'')
      (bind "${mod} + SHIFT + RIGHT" ''hl.dsp.window.swap({ direction = "right" })'')
      (bind "${mod} + SHIFT + UP" ''hl.dsp.window.swap({ direction = "up" })'')
      (bind "${mod} + SHIFT + DOWN" ''hl.dsp.window.swap({ direction = "down" })'')
    ])
    (rowKeys "Windows" "Grow / shrink" ["Super" "=" "−"] (
      resizeBinds resizeStep ["${mod} + EQUAL" "${mod} + SHIFT + PLUS"]
      ++ resizeBinds (-resizeStep) ["${mod} + MINUS" "${mod} + SHIFT + UNDERSCORE"]
    ))
    (rowKeys "Windows" "Move with mouse" ["Super" "Left drag"] [(bindm "${mod} + mouse:272" "hl.dsp.window.drag()")])
    (rowKeys "Windows" "Resize with mouse" ["Super" "Right drag"] [(bindm "${mod} + mouse:273" "hl.dsp.window.resize()")])
    # Super held for a drag is not a held Super: these tell the hold above, and pass the
    # press through to the drag binds.
    {
      binds = [
        (bindWith {non_consuming = true;} "${mod} + mouse:272" "function() qs_super_used() end")
        (bindWith {non_consuming = true;} "${mod} + mouse:273" "function() qs_super_used() end")
      ];
    }
    (rowKeys "Windows" "Zoom" ["Super" "Scroll"] [
      (bind "${mod} + mouse_up" (zoomBy 1))
      (bind "${mod} + mouse_down" (zoomBy (-1)))
    ])
    # Bound, but not on the sheet: the design keeps Windows at ten rows, and Zoom is its other half.
    {binds = [(bind "${mod} + 0" ''function() hl.config({ cursor = { zoom_factor = 1 } }) end'')];}

    (row "Workspaces" "Overview" [(bind "${mod} + TAB" (exec "qs ipc call overview toggle"))])
    (rowKeys "Workspaces" "Go to workspace" ["Super" "1–9"] (map (i: bind "${mod} + ${toString i}" "hl.dsp.focus({ workspace = ${toString i} })") workspaces))
    (rowKeys "Workspaces" "Move window to workspace" ["Super" "Shift" "1–9"] (map (i: bind "${mod} + SHIFT + ${toString i}" "hl.dsp.window.move({ workspace = ${toString i} })") workspaces))
    # Three fingers: sideways moves between workspaces, up opens the Overview. The swipe
    # stays on the monitor's own workspaces, so it honours the pinning above.
    {
      group = "Workspaces";
      desc = "Switch workspace";
      keys = ["3 fingers" "←" "→"];
      binds = [];
      gestures = [
        {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        }
      ];
    }
    {
      group = "Workspaces";
      desc = "Overview from the trackpad";
      keys = ["3 fingers" "↑"];
      binds = [];
      gestures = [
        {
          fingers = 3;
          direction = "up";
          action = mkLuaInline ''function() hl.exec_cmd("qs ipc call overview toggle") end'';
        }
      ];
    }

    (row "Shell surfaces" "Launcher" [(bind "${mod} + SPACE" (exec "qs ipc call launcher toggle"))])
    (row "Shell surfaces" "Control centre" [(bind "ALT + A" (exec "qs ipc call control toggle"))])
    (row "Shell surfaces" "Calendar" [(bind "ALT + C" (exec "qs ipc call calendar toggle"))])
    (row "Shell surfaces" "Theme" [(bind "ALT + T" (exec "qs ipc call theme toggle"))])
    (row "Shell surfaces" "Profiles" [(bind "ALT + P" (exec "qs ipc call profiles toggle"))])
    (row "Shell surfaces" "Nearby" [(bind "ALT + N" (exec "qs ipc call nearby toggle"))])
    (rowKeys "Shell surfaces" "Wallpaper" ["Super" "Ctrl" "Space"] [(bind "CTRL + ${mod} + SPACE" (exec "qs ipc call wallpaper toggle"))])
    (row "Shell surfaces" "Session menu" [(bind "${mod} + ESCAPE" (exec "qs ipc call session toggle"))])
    (row "Shell surfaces" "Lock" [(bind "${mod} + L" (exec "lock-session"))])

    (row "Capture" "Region" (onPrint "" (exec "qs ipc call capture region")))
    (row "Capture" "Screen" (onPrint "ALT + " (exec "qs ipc call capture output")))
    (row "Capture" "All screens" (onPrint "${mod} + CTRL + " (exec "qs ipc call capture screen")))
    # PrtSc sends Shift+Meta+S, which keyd turns into Print only as a three-key chord. With
    # SUPER already held its press is too early to join, so SUPER + PrtSc arrives as
    # SUPER + SHIFT + S instead; it is bound too and listed once, as Super PrtSc.
    (row "Capture" "Colour picker" (onPrint "${mod} + " (exec "qs ipc call screentools run colour")
        ++ [(bind "${mod} + SHIFT + S" (exec "qs ipc call screentools run colour"))]))
    # Region, window, text, QR code and colour grabs; Print stays a direct region capture.
    (row "Capture" "Screen tools" [(bind "ALT + S" (exec "qs ipc call screentools toggle"))])
    # Opens the picker, or stops and saves a running recording.
    (row "Capture" "Record screen" [(bind "ALT + R" (exec "qs ipc call recorder toggle"))])

    (row "Media" "Play / pause" [(bind "XF86AudioPlay" (exec "playerctl play-pause"))])
    (rowKeys "Media" "Previous / next" ["Prev" "Next"] [
      (bind "XF86AudioPrev" (exec "playerctl previous"))
      (bind "XF86AudioNext" (exec "playerctl next"))
    ])
    (row "Media" "Mute" [(bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))])
    # Routed through Quickshell so the OSD shows even at the limits.
    (rowKeys "Media" "Volume" ["Vol −" "Vol +"] [
      (bindel "XF86AudioLowerVolume" (exec "qs ipc call volume down"))
      (bindel "XF86AudioRaiseVolume" (exec "qs ipc call volume up"))
    ])
    (rowKeys "Media" "Brightness" ["Bri −" "Bri +"] [
      (bindel "XF86MonBrightnessDown" (exec "qs ipc call brightness down"))
      (bindel "XF86MonBrightnessUp" (exec "qs ipc call brightness up"))
    ])

    # Dictation: tap to start and stop, or hold to talk. Letting go of SUPER first skips
    # the release, which leaves it recording as if tapped. The second is the same, cleaned
    # up by a model before it is typed; see home/dictation.nix.
    (rowKeys "Dictation" "Dictate, tap or hold" ["Super" "D"] [
      (bind "${mod} + D" (exec "dictate press"))
      (bindWith {release = true;} "${mod} + D" (exec "dictate release"))
    ])
    (rowKeys "Dictation" "Dictate and clean up" ["Super" "Shift" "D"] [
      (bind "${mod} + SHIFT + D" (exec "dictate press --post-process"))
      (bindWith {release = true;} "${mod} + SHIFT + D" (exec "dictate release --post-process"))
    ])
  ];
in {
  # Captures (Services/Captures.qml) are saved into XDG_SCREENSHOTS_DIR, created here.
  home.file."Pictures/screenshots/.keep".text = "";

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    # UWSM owns the user systemd session.
    systemd.enable = false;

    # Loaded ahead of the settings, so plugin options below resolve.
    plugins = [pkgs.dragpile];

    # Super held alone shows the cheatsheet; see superHold above.
    extraConfig = superHold;

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
          gaps_out = gapsOut;

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
          rounding = 12;
          blur = {
            enabled = true;
            size = 16;
            passes = 3;
            vibrancy = 0.1696;
          };
          shadow.enabled = false;
        };

        animations.enabled = true;

        # Laptop touchpad swipes: a shorter drag than the 300 default, committing at a third
        # of it (or on a quick flick) rather than half. Workspaces are a fixed 1-9, some of
        # them pinned to a monitor, so a swipe off the last one must not open a tenth. The
        # axis locks early so a diagonal swipe does not wobble.
        gestures = {
          workspace_swipe_distance = 250;
          workspace_swipe_cancel_ratio = 0.3;
          workspace_swipe_min_speed_to_force = 20;
          workspace_swipe_create_new = false;
          workspace_swipe_direction_lock = true;
          workspace_swipe_direction_lock_threshold = 15;
        };

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
        # Workspace switches are instant, by choice; a swipe still switches, it just doesn't slide.
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
        {
          leaf = "specialWorkspace";
          enabled = false;
          speed = 1;
          bezier = "default";
        }
        {
          leaf = "specialWorkspaceIn";
          enabled = false;
          speed = 1;
          bezier = "default";
        }
        {
          leaf = "specialWorkspaceOut";
          enabled = false;
          speed = 1;
          bezier = "default";
        }
        {
          leaf = "zoomFactor";
          enabled = true;
          speed = 4.1;
          bezier = "easeOutQuint";
        }
      ];

      # Both come from the keybind table at the top of this file.
      gesture = keybinds.gestures keyRows;
      bind = keybinds.binds keyRows;

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

        # The screenshot tray's Annotate opens satty on one capture; it is a short-lived
        # editor over the work, not a window to tile.
        {
          match.class = "^com\\.gabm\\.satty$";
          float = true;
          center = true;
          size = "monitor_w*0.7 monitor_h*0.75";
        }

        # Chromium's picture-in-picture window shares the browser's class, so it is told
        # apart by its title. It becomes a corner thumbnail a quarter of the monitor
        # wide, in the browser's own aspect ratio, that follows you between workspaces. Move
        # sees the window as it opened, before the size rule, so the corner is worked out from
        # the final size instead of window_w and window_h.
        {
          match.title = "^(?i)picture[ -]in[ -]picture$";
          float = true;
          pin = true;
          keep_aspect_ratio = true;
          no_initial_focus = true;
          size = "monitor_w*0.25 window_h*(monitor_w*0.25/window_w)";
          move = "monitor_w*0.75-${toString gapsOut} monitor_h-window_h*(monitor_w*0.25/window_w)-${toString gapsOut}";
        }

        # Modal dialogs open centred in front of their window. Portal file choosers are
        # empty lists until they fill, so they get room to browse.
        {
          match.modal = true;
          float = true;
          center = true;
        }
        {
          match.class = "^(xdg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\.desktop\\.gtk)$";
          float = true;
          center = true;
          size = "monitor_w*0.6 monitor_h*0.65";
        }
      ];

      # Quickshell panels animate themselves, so no compositor fade.
      layer_rule = [
        {
          match.namespace = "quickshell-(bar|launcher|control|wallpaper|theme|recorder|calendar|session|profiles|nearby|auth|screentools|captures|sharing|notifications|osd|panel|overview|cheatsheet|sharepicker)";
          no_anim = true;
        }
      ];

      # Block bindings and helpers until Quickshell secures every output.
      on = [
        {
          _args = [
            "hyprland.start"
            (mkLuaInline ''
              function()
                hl.dispatch(hl.dsp.submap("lockdown"))
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

    # The catchall registers lockdown and blocks normal startup bindings.
    submaps.lockdown.settings.bind = [
      (bind "catchall" "hl.dsp.no_op()")
    ];
  };

  # mpv's controls scale with window height, and the window.open hook above opens
  # big videos smaller than mpv would; 1.4 gives back the size they had in a 4K
  # video's window. Fullscreen controls are unchanged.
  xdg.configFile."mpv/script-opts/osc.conf".text = "scalewindowed=1.4\n";

  # The screen-share portal asks the shell's picker, and the stock one when the shell is not
  # there (pkgs/share-picker). A restore token is offered per request, not by default.
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      custom_picker_binary = ${pkgs.share-picker}/bin/share-picker
      allow_token_by_default = false
    }
  '';

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # before_sleep_cmd raises the event that runs lock_cmd.
        lock_cmd = "lock-session";
        before_sleep_cmd = "loginctl lock-session";
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

  # The cheatsheet's content, generated from keyRows so it cannot drift from the binds. Like the
  # emoji table below it sits outside the out-of-store config tree, so it is read from a fixed
  # path; see Services/Keybinds.qml.
  xdg.dataFile."quickshell/bindings.json".text = keybinds.cheatsheet keyRows;

  # The launcher's emoji table, generated from nixpkgs' Unicode data. The config above is
  # out of store, so it reads this from a fixed path; see Services/EmojiSearch.qml.
  xdg.dataFile."quickshell/emoji.tsv".source = "${pkgs.quickshell-emoji}/share/quickshell/emoji.tsv";

  # The interface sounds, synthesised with sox. Read from a fixed path like the table above;
  # see Services/Sounds.qml.
  xdg.dataFile."quickshell/sounds".source = "${pkgs.quickshell-sounds}/share/quickshell/sounds";

  # The account picture, read by the lock screen. Out of store, so replacing
  # profile.jpg in this repo shows on the next lock without a rebuild.
  home.file.".face" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/profile.jpg";
    force = true;
  };
}
