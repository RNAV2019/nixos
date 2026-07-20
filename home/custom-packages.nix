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
  in pkgs.rustPlatform.buildRustPackage {
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
  in pkgs.rustPlatform.buildRustPackage {
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
  in pkgs.rustPlatform.buildRustPackage {
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
  ];
}
