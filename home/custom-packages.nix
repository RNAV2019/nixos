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
    runtimeInputs = [pkgs.quickshell pkgs.coreutils];
    text = ''
      if ! qs ipc call lock lock >/dev/null 2>&1; then
        quickshell --daemonize --no-duplicate >/dev/null 2>&1 || true

        accepted=false
        for _ in $(seq 1 100); do
          sleep 0.1
          if qs ipc call lock lock >/dev/null 2>&1; then
            accepted=true
            break
          fi
        done

        if [[ "$accepted" != true ]]; then
          echo "lock-session: quickshell did not accept a lock request" >&2
          exit 1
        fi
      fi

      for _ in $(seq 1 100); do
        if [[ "$(qs ipc call lock secure 2>/dev/null || true)" == true ]]; then
          exit 0
        fi
        sleep 0.1
      done

      echo "lock-session: compositor did not secure the session" >&2
      exit 1
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

  # T3 Code nightlies are AppImage-only.
  # Update `version` from `gh api repos/pingdotgg/t3code/releases -q '.[0].tag_name'`, then run:
  # nix store prefetch-file "https://github.com/pingdotgg/t3code/releases/download/v<version>/T3-Code-<version>-x86_64.AppImage"
  t3code-nightly = let
    pname = "t3code-nightly";
    version = "0.0.41-nightly.20260910.1486";
    src = pkgs.fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-qkocCKGth9xpZoSB7K22otT5SF5Bctxmz5IPpAw53Bk=";
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
