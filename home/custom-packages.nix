{ config, pkgs, ... }:
let

  quasar = pkgs.buildGoModule {
    pname = "quasar";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "quasar";
      rev = "9ff1c7a5b72ed2876d9ceffe1a6fde6ab0303b30";
      hash = "sha256-wlFt3OpZfPsssDW/Di6uirhusEQjUB/WoQAnvTFHXtU=";
    };
    vendorHash = "sha256-U4HAzSi3BT4yPGceEPnvSyQkl1UoeP3mmSHZsgnEffw=";
  };

  project-picker = pkgs.rustPlatform.buildRustPackage {
    pname = "project-picker";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "project-picker";
      rev = "428b15e90d2a2ce388e64c8d2a547bb03f013fa0";
      hash = "sha256-Ia+e7d4tYqoThYq3ngvUXn5UUFZJ4FJRdFAP5SXfhRM=";
    };
    cargoHash = "sha256-eGF9ASlbZaeg+2m0vEBZt0+1fGjWleUXkrTy+UbgW4A=";
  };

in
{
  home.packages = [
    quasar
    project-picker
  ];
}
