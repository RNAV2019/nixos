{
  config,
  pkgs,
  ...
}: let
  gen-commit = import ./gen-commit.nix {inherit pkgs;};

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

  mycelium = let
    runtimeLibs = [
      pkgs.wayland
      pkgs.libxkbcommon
      pkgs.vulkan-loader
    ];
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "mycelium";
      rev = "3628eaf0a0fe5234fcc91dd789bbb0422f75ac65";
      hash = "sha256-9d2JS3wjiV6eF3hLoP71XL7Ig5JtAWBRYqsf7xoLa3g=";
    };
  in
    pkgs.rustPlatform.buildRustPackage {
      pname = "mycelium";
      version = "0.1.0";
      inherit src;
      cargoLock.lockFile = "${src}/Cargo.lock";

      buildInputs = runtimeLibs;
      nativeBuildInputs = [pkgs.makeWrapper];

      postInstall = ''
        wrapProgram $out/bin/mycelium \
          --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs}
      '';
    };

  cherry = let
    runtimeLibs = [
      pkgs.wayland
      pkgs.libxkbcommon
      pkgs.vulkan-loader
    ];
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "cherry";
      rev = "c9242329ea16a2da857d5b231702d07cb041813d";
      hash = "sha256-nMM04+ki4ckS57YKMexgHiNMy2g0PtIoU7N0poLnxo8=";
    };
  in
    pkgs.rustPlatform.buildRustPackage {
      pname = "cherry";
      version = "0.1.0";
      inherit src;
      cargoLock.lockFile = "${src}/Cargo.lock";

      buildInputs = runtimeLibs;
      nativeBuildInputs = [pkgs.makeWrapper pkgs.pkg-config pkgs.wayland-protocols];

      postInstall = ''
        wrapProgram $out/bin/cherry \
          --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs} \
          --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.awww pkgs.libnotify]}
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
    version = "0.0.39-nightly.20260906.1303";
    src = pkgs.fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-zKeGYaBXoRj4Y1XHFXA6/mOsNKp2eUO/j+G6rJYAjT0=";
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

  # Hyprland's misc:initial_workspace_tracking pins the first window of an
  # exec'd process to the workspace that was active at spawn time. These
  # launchers are daemons that map their window lazily on the first toggle, so
  # a login-time exec left them opening on workspace 1 forever after. systemd
  # spawns them outside that tracking, so every window follows the active
  # workspace — including the first.
  launcherDaemon = name: pkg: {
    Unit = {
      Description = "${name} launcher daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkg}/bin/${name}";
      # `--kill` is an intentional exit; only restart on a crash.
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install.WantedBy = ["graphical-session.target"];
  };

  ani-cli = pkgs.ani-cli.overrideAttrs {
    version = "5.0";
    src = pkgs.fetchFromGitHub {
      owner = "pystardust";
      repo = "ani-cli";
      tag = "v5.0";
      hash = "sha256-rRQESi0Skoyf1jy/dRRK6ooKRPQhkak107kk5ulwZYI=";
    };
  };
in {
  home.packages = [
    ani-cli
    cherry
    lock-session
    mycelium
    start-desktop
    gen-commit
    forward-dev
    t3code-nightly
  ];

  systemd.user.services = {
    cherry = launcherDaemon "cherry" cherry;
    mycelium = launcherDaemon "mycelium" mycelium;
  };
}
