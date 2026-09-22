# Helium follows the desktop theme through Chrome theme extensions, one per theme, built from
# rose-pine/google-chrome's template role for role so the dark one is shaded the same way.
#
# Chromium has no way for an extension to switch themes: enabling a theme applies it, but the
# theme it replaces is uninstalled a moment later and nothing inside the browser can load it
# again. The DevTools protocol can (Extensions.loadUnpacked), so `helium` here is a launcher that
# starts the browser with a private DevTools pipe, loads the active theme, and loads the next
# one whenever theme-switch writes a new name. Loading a theme applies it to every open window
# at once.
{
  pkgs,
  lib,
  helium,
  stateDir,
}: let
  palettes = import ./palettes.nix;
  ids = lib.attrNames palettes;

  # Fixed keys give the extensions fixed IDs, which the launcher uninstalls by. Only the public
  # halves exist: unpacked extensions are never signed. Nix cannot hash the decoded key, so each
  # ID is written out and checked at build time.
  keys = {
    rose-pine = {
      id = "lcaeofnkgjinbeemhdbhpmmpalfacafd";
      key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqsvJf5ox3Bcvfp7dVIkRfxKMo4DsO+YjbVDV+6B9H/L6JT5wfBncqGJRjhuiqmVlCe2ZpIV0YQDZC5TkFRTWXsBBJw6rEpp3mkOgguC3370mIFlwyxyaxacjiDwc0z/ccI9yf1Yl/hLfBUM0QiXhNZY1oO1Yn+tvSSOp040N30STBFDtLD8XRis67XdJdX/2XYlGT54ovmwfqR3tzsUcngKAwCPGzFYNcBZMSU/xTmC3nc2ddTE9MG+/N/l7zd6GdFHy0RXxKE8n0mtYH0NM2GCPTTwmTpBDa/idTHaEi32a4LXT+NIkKXn3z95x5qEi1oQe/g5hWAua4G4XUlhcAQIDAQAB";
    };
    dark = {
      id = "bfcdjeihplkejjdcflicedhgmigmfocc";
      key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxUsUkNVuwClmpg1RIXp6DJ6ZOXzjwKVSXj22TTxbCwfRCkOrkdViDGn8GeOOCkCR6th+UaU75TRoNUl3Piw6PS0c6U67SmsuDG3/+PJBEwkkHc3IJQt6Cu8GT1Nt8e8Rp8VBEUn9AEnIWH7XFTe+e32UGf5x7g21NBaDZoNfqkjbJ3/wq7i5oI96L3ch/Pi04kZ1u5lC9eBWkE1wm1A5tsHXGnW/m2QRi9O27jbjllXfa93YBIy5mLiU6zgLbwNGh+AgtN6IgdI/JjK6izQZV5R4hCz1p+499zOGNa8DaPRr2IHtrtGG11asY+34N1dqU7gGDriJN712s70p2ChwqQIDAQAB";
    };
  };

  rgb = hex: let
    h = lib.removePrefix "#" hex;
  in
    map (i: lib.fromHexString (builtins.substring i 2 h)) [0 2 4];

  # rose-pine/google-chrome's manifest for its main variant, each colour replaced by the role
  # it was generated from. The frame and toolbar are drawn from solid swatch images.
  manifest = id: p: {
    manifest_version = 3;
    name = p.label;
    version = "2.0.0";
    inherit (keys.${id}) key;
    theme = {
      images = {
        theme_frame = "swatches/base.png";
        theme_toolbar = "swatches/surface.png";
        theme_frame_incognito = "swatches/med.png";
      };
      colors = {
        frame = rgb p.overlay;
        frame_inactive = rgb p.overlay;
        bookmark_text = rgb p.text;
        button_background = rgb p.base;
        tab_background_text = rgb p.subtle;
        tab_background_text_inactive = rgb p.muted;
        tab_text = rgb p.text;
        toolbar = rgb p.overlay;
        toolbar_button_icon = rgb p.text;
        frame_incognito = [0 0 0];
        frame_incognito_inactive = rgb p.highlightMed;
        tab_background_text_incognito = rgb p.text;
        tab_background_text_incognito_inactive = rgb p.subtle;
        omnibox_text = rgb p.rose;
        omnibox_background = rgb p.base;
        ntp_background = rgb p.base;
        ntp_header = rgb p.surface;
        ntp_link = rgb p.subtle;
        ntp_text = rgb p.subtle;
      };
      tints = lib.genAttrs ["buttons" "frame" "frame_inactive" "frame_incognito" "frame_incognito_inactive"] (_: [(-1) (-1) (-1)]);
      properties = {
        ntp_background_alignment = "bottom";
        ntp_logo_alternate = 1;
      };
    };
  };

  themeExtension = id: let
    p = palettes.${id};
    swatches = {
      base = p.base;
      surface = p.surface;
      med = p.highlightMed;
    };
  in
    pkgs.runCommand "helium-theme-${id}" {nativeBuildInputs = [pkgs.imagemagick];} ''
      id="$(echo ${keys.${id}.key} | base64 -d | sha256sum | cut -c1-32 | tr 0-9a-f a-p)"
      if [ "$id" != ${keys.${id}.id} ]; then
        echo "helium-theme-${id}: key gives ID $id, not ${keys.${id}.id}" >&2
        exit 1
      fi
      mkdir -p $out/swatches
      cp ${pkgs.writeText "manifest.json" (builtins.toJSON (manifest id p))} $out/manifest.json
      ${lib.concatStrings (lib.mapAttrsToList (name: colour: ''
          magick -size 120x120 xc:'${colour}' -define png:exclude-chunks=date,time $out/swatches/${name}.png
        '')
        swatches)}
    '';

  launcher = pkgs.writeShellApplication {
    name = "helium";
    runtimeInputs = [pkgs.coreutils pkgs.inotify-tools];
    text = ''
      state="${stateDir}"
      browser="${helium}/bin/helium"

      themeDir() {
        case "$1" in
      ${lib.concatMapStrings (id: "    ${id}) echo ${themeExtension id} ;;\n") ids}    *) return 1 ;;
        esac
      }
      themeId() {
        case "$1" in
      ${lib.concatMapStrings (id: "    ${id}) echo ${keys.${id}.id} ;;\n") ids}    esac
      }
      themeIds=(${lib.concatMapStringsSep " " (id: keys.${id}.id) ids})

      # The DevTools pipe: Chromium reads commands from fd 3 and writes replies to fd 4, each a
      # JSON message ending in a NUL. The browser gets both FIFOs read-write, so it holds a
      # writer on its own input: Chromium closes itself when that pipe reaches EOF, and this
      # way a launcher that dies never takes the browser with it. Anything going wrong before
      # the browser starts falls back to plain Helium.
      fifos="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/helium-theme.XXXXXX")" || exec "$browser" "$@"
      if ! mkfifo "$fifos/in" "$fifos/out"; then
        rm -rf "$fifos"
        exec "$browser" "$@"
      fi
      exec 5<>"$fifos/in" 6<>"$fifos/out"
      rm -rf "$fifos"

      # If Helium is already running, this browser hands its arguments to that one and exits,
      # and so does the launcher; the running one's launcher keeps doing the theming.
      "$browser" --remote-debugging-pipe --enable-unsafe-extension-debugging "$@" 3<&5 4<&6 5<&- 6<&- &
      pid=$!
      trap 'kill -TERM "$pid" 2>/dev/null || true' TERM INT HUP

      n=0
      # Sends one command and waits for its reply; fails on an error reply, or on no reply
      # within ten seconds or before the browser exits (the pipe never reaches EOF).
      call() {
        n=$((n + 1))
        printf '{"id":%d,"method":"%s","params":%s}\0' "$n" "$1" "$2" >&5
        local reply tries=0
        while ((tries++ < 20)) && kill -0 "$pid" 2>/dev/null; do
          if IFS= read -r -d "" -t 0.5 reply <&6; then
            case "$reply" in
            "{\"id\":$n,"*)
              [[ $reply != *'"error":'* ]]
              return
              ;;
            esac
          fi
        done
        return 1
      }

      # Chromium keeps a replaced theme installed but disabled for a while, and loading a
      # disabled extension again leaves it disabled, so the wanted theme is uninstalled first.
      # The others go after it: uninstalling the theme in use would flash Helium's own colours.
      apply() {
        local name dir want id
        name="$(cat "$state/name" 2>/dev/null)" || return 0
        dir="$(themeDir "$name")" || return 0
        want="$(themeId "$name")"
        call Extensions.uninstall "{\"id\":\"$want\"}" || true
        call Extensions.loadUnpacked "{\"path\":\"$dir\"}" || return 1
        for id in "''${themeIds[@]}"; do
          if [ "$id" != "$want" ]; then
            call Extensions.uninstall "{\"id\":\"$id\"}" || true
          fi
        done
      }

      mkdir -p "$state"
      coproc watch { exec inotifywait -q -m -e close_write,moved_to --format %f "$state"; }
      # Kept apart from the array, which bash unsets when the watcher exits.
      watchFd=''${watch[0]}

      # The extension system comes up a little after the browser does.
      for _ in $(seq 40); do
        apply && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.25
      done

      while kill -0 "$pid" 2>/dev/null; do
        if read -r -t 5 file <&"$watchFd"; then
          if [ "$file" = name ]; then
            apply || true
          fi
        elif (($? <= 128)); then
          # The watcher is gone; just wait for the browser.
          wait "$pid" || true
        fi
      done

      # shellcheck disable=SC2154 # set by coproc
      kill "$watch_PID" 2>/dev/null || true
      wait "$pid"
    '';
  };
in
  # Everything from Helium except bin/helium, which is the launcher.
  pkgs.symlinkJoin {
    name = "helium-themed";
    paths = [helium];
    postBuild = ''
      rm $out/bin/helium
      ln -s ${lib.getExe launcher} $out/bin/helium
    '';
  }
