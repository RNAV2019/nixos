{
  description = "Ryan's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    helium-browser = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    # Helix fork carrying the Steel plugin runtime; same 25.07.1 base as nixpkgs.
    helix-steel = {
      url = "github:mattwparas/helix/steel-event-system";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Typst notes TUI, installed as `note`; its tinymist preview lives in home/editors.nix.
    note-tui = {
      url = "github:RNAV2019/note-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust toolchains pinned to upstream release manifests rather than nixpkgs.
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Decryption key lives at /etc/nixos-secrets/age.key, never in this repo.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    hyprland,
    helium-browser,
    llm-agents,
    helix-steel,
    note-tui,
    fenix,
    sops-nix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    gen-commit = import ./home/gen-commit.nix {inherit pkgs;};
    ical-agenda = import ./home/ical-agenda.nix {inherit pkgs;};
  in {
    packages.${system} = {
      inherit gen-commit ical-agenda;
      default = gen-commit;
    };

    checks.${system} = {
      gen-commit = import ./tests/gen-commit.nix {
        inherit pkgs;
        genCommit = gen-commit;
      };

      ical-agenda = import ./tests/ical-agenda.nix {
        inherit pkgs;
        icalAgenda = ical-agenda;
      };

      quickshell-qmlformat = pkgs.runCommand "quickshell-qmlformat" {
        nativeBuildInputs = [pkgs.qt6Packages.qtdeclarative];
      } ''
        cp -R ${./home/quickshell} quickshell
        chmod -R u+w quickshell
        find quickshell -type f -name '*.qml' -print0 | while IFS= read -r -d "" file; do
          qmlformat --force --inplace "$file"
        done
        touch "$out"
      '';
    };

    # Named after each hostname so a bare `nixos-rebuild --flake ~/nixos` picks
    # the right one. Per-machine config lives in hosts/<name>.
    nixosConfigurations = let
      mkHost = hostName:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/${hostName}
            ./modules/system
            {networking.hostName = hostName;}

            sops-nix.nixosModules.sops

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Preserve unmanaged files during activation.
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.ryan = import ./home/default.nix;
              home-manager.extraSpecialArgs = {inherit hyprland helium-browser llm-agents helix-steel note-tui fenix;};
            }
          ];
          specialArgs = {inherit hyprland helium-browser llm-agents helix-steel note-tui fenix;};
        };
    in {
      ryans-nixos = mkHost "ryans-nixos";
    };
  };
}
