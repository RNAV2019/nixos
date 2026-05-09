{ config, pkgs, ... }:
let

  quasar = pkgs.buildGoModule {
    pname = "quasar";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "quasar";
      rev = "main";
      hash = "sha256-BBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    vendorHash = null;
  };

  project-picker = pkgs.rustPlatform.buildRustPackage {
    pname = "project-picker";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "project-picker";
      rev = "main";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    cargoHash = "sha256-DDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

in
{
  home.packages = [
    quasar
    project-picker
  ];
}
