{
  config,
  pkgs,
  ...
}: let
  gen-commit = import ./gen-commit.nix {inherit pkgs;};
  ical-agenda = import ./ical-agenda.nix {inherit pkgs;};

  # Start Quickshell if needed and wait until every output is locked.
  lock-session = pkgs.writeShellApplication {
    name = "lock-session";
    runtimeInputs = [
      pkgs.quickshell
      pkgs.coreutils
      pkgs.systemd
      config.wayland.windowManager.hyprland.package
    ];
    text = ''
      # Failure leaves the desktop open and the shell gone, so Hyprland shows the warning.
      warn_unlocked() {
        echo "lock-session: $1" >&2
        hyprctl notify 3 15000 "rgb(eb6f92)" "Session is NOT locked: $1" >/dev/null 2>&1 || true
        exit 1
      }

      if ! qs ipc call lock lock >/dev/null 2>&1; then
        # Start via the user manager so it gets the session environment even from a TTY.
        # No --daemonize: systemd would reap the forked child along with the shell.
        systemd-run --user --collect --quiet --unit=quickshell-shell \
          "$(command -v quickshell)" >/dev/null 2>&1 || true

        accepted=false
        for _ in $(seq 1 100); do
          sleep 0.1
          if qs ipc call lock lock >/dev/null 2>&1; then
            accepted=true
            break
          fi
        done

        if [[ "$accepted" != true ]]; then
          warn_unlocked "quickshell did not accept a lock request"
        fi
      fi

      for _ in $(seq 1 100); do
        if [[ "$(qs ipc call lock secure 2>/dev/null || true)" == true ]]; then
          exit 0
        fi
        sleep 0.1
      done

      warn_unlocked "the compositor did not secure the session"
    '';
  };

  forward-dev = pkgs.writeShellApplication {
    name = "forward-dev";
    runtimeInputs = [pkgs.cloudflared];
    text = ''
      PORT="''${1:-3000}"
      DOMAIN="dev.ryannavsaria.co.uk"
      TUNNEL_NAME="dev-tunnel"

      echo "Forwarding https://$DOMAIN --> http://127.0.0.1:$PORT"
      echo "Press Ctrl+C to stop forwarding."

      cloudflared tunnel --url "http://localhost:$PORT" run "$TUNNEL_NAME"
    '';
  };

  # Desktop helpers are held until the lock has securely covered every output.
  start-desktop = pkgs.writeShellApplication {
    name = "start-desktop";
    runtimeInputs = [
      lock-session
      pkgs.awww
      pkgs.cliphist
      pkgs.coreutils
      pkgs.networkmanagerapplet
      pkgs.wl-clipboard
    ];
    text = ''
      lock-session

      # awww-daemon is a systemd user unit; just wait for its socket.
      for _ in $(seq 1 50); do
        if awww query >/dev/null 2>&1; then
          awww img "$HOME/.local/share/wallpaper/current"
          break
        fi
        sleep 0.1
      done

      nm-applet --indicator &
      cliphist wipe || true
      wl-paste --type text --watch cliphist store &
      wl-paste --type image --watch cliphist store &
      wait
    '';
  };

  # T3 Code nightlies are AppImage-only. Get `version` from the latest release tag
  # and the hash via `nix store prefetch-file` on the AppImage URL.
  t3code-nightly = let
    pname = "t3code-nightly";
    version = "0.0.43-nightly.20260924.2213";
    src = pkgs.fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-rOb/nY6pc8LBrhdHwizWpUG4xkK/AK53osEgTzvwNiI=";
    };
    appimageContents = pkgs.appimageTools.extract {inherit pname version src;};
  in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      # The FHS environment cannot provide a setuid chrome-sandbox.
      extraInstallCommands = ''
        install -Dm644 ${appimageContents}/t3code.desktop \
          $out/share/applications/${pname}.desktop
        install -Dm644 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/t3code.png \
          $out/share/icons/hicolor/512x512/apps/t3code.png

        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} --no-sandbox %U'
      '';
    };

  ani-cli = pkgs.ani-cli.overrideAttrs {
    version = "5.1";
    src = pkgs.fetchFromGitHub {
      owner = "pystardust";
      repo = "ani-cli";
      tag = "v5.1";
      hash = "sha256-lPQA3iO3F/9NS2IziQccsJ3aai6WMQy6YObdB3mDCZA=";
    };
  };
in {
  home.packages = [
    ani-cli
    lock-session
    start-desktop
    gen-commit
    ical-agenda
    forward-dev
    t3code-nightly
  ];

}
