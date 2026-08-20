{
  config,
  pkgs,
  ...
}: let
  gen-commit = import ./gen-commit.nix {inherit pkgs;};

  hyprlock-music = pkgs.writeShellApplication {
    name = "hyprlock-music";
    runtimeInputs = [pkgs.playerctl];
    text = ''
      status=$(playerctl status 2>/dev/null || true)
      if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
        playerctl metadata --format "{{title}} - {{artist}}" 2>/dev/null || true
      fi
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

  project-picker = let
    runtimeLibs = [
      pkgs.wayland
      pkgs.libxkbcommon
      pkgs.vulkan-loader
    ];
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "project-picker";
      rev = "590f5c9931ae852b81efef94db6988e1cf23957f";
      hash = "sha256-aOzgjytqZhfnW9QiWZdEoUpP1/8W5kdnDtnaZrVTjEI=";
    };
  in
    pkgs.rustPlatform.buildRustPackage {
      pname = "project-picker";
      version = "1.0.0";
      inherit src;
      cargoLock.lockFile = "${src}/Cargo.lock";

      buildInputs = runtimeLibs;
      nativeBuildInputs = [pkgs.makeWrapper];

      postInstall = ''
        wrapProgram $out/bin/project-picker \
          --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs}
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
      rev = "2229b3992861c0c2ad901d192d50e0e3155765bd";
      hash = "sha256-W8/TiYPMrTAGQsGdW2/62Tx1oC1rcFxiWVEkKePTj4Y=";
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
      rev = "e28da24ff0c1732cf9fe7bcdefe3f25f68fed477";
      hash = "sha256-ywUSrmo5GDdn0j5/9u0B8WCDQc010qHl2mXXv5JQh8I=";
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

  # T3 Code nightly. Upstream only ships an AppImage for Linux nightlies, so we
  # wrap that rather than building from source like nixpkgs' stable t3code does.
  #
  # To bump, find the newest nightly tag:
  #   gh api repos/pingdotgg/t3code/releases -q '.[0].tag_name'
  # then update `version` below and re-fetch the hash:
  #   nix store prefetch-file "https://github.com/pingdotgg/t3code/releases/download/v<version>/T3-Code-<version>-x86_64.AppImage"
  t3code-nightly = let
    pname = "t3code-nightly";
    version = "0.0.34-nightly.20260820.1146";
    src = pkgs.fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-kZcyVxYUCeBdUHO66JqNDi/YDfEjFQj9vyNslfLWwF0=";
    };
    appimageContents = pkgs.appimageTools.extract {inherit pname version src;};
  in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      # --no-sandbox is required: chrome-sandbox needs setuid root, which it
      # cannot have inside the FHS env. Wayland needs no flags here because
      # NIXOS_OZONE_WL=1 is already set in home/default.nix.
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
    version = "4.14";
    src = pkgs.fetchFromGitHub {
      owner = "pystardust";
      repo = "ani-cli";
      tag = "v4.14";
      hash = "sha256-OyCKDN89sBz59+3JncMDyNOq8UMqqjara+A0Owo3oko=";
    };
  };
in {
  home.packages = [
    ani-cli
    cherry
    hyprlock-music
    project-picker
    mycelium
    gen-commit
    forward-dev
    t3code-nightly
  ];
}
