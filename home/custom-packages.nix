{ config, pkgs, ... }:
let

  quasar = pkgs.buildGoModule {
    pname = "quasar";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "quasar";
      rev = "main";
      hash = "sha256-u3pUyvQhEYvQMceKfE33hfbI/JsVfRjvPTT/cTJ8KKQ=";
    };
    vendorHash = "sha256-U4HAzSi3BT4yPGceEPnvSyQkl1UoeP3mmSHZsgnEffw=";
  };

  project-picker = pkgs.rustPlatform.buildRustPackage {
    pname = "project-picker";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "RNAV2019";
      repo = "project-picker";
      rev = "main";
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
