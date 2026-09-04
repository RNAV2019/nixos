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

    # Typst notes TUI, installed as the `note` command. The tinymist preview
    # it drives is configured in home/editors.nix.
    note-tui = {
      url = "github:RNAV2019/note-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust toolchains straight from the upstream release manifests, so every
    # component is pinned to one release rather than to the nixpkgs bump.
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets. The age identity that decrypts secrets/secrets.yaml lives at
    # /etc/nixos-secrets/age.key and is never in this repo.
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
  in {
    packages.${system} = {
      inherit gen-commit;
      default = gen-commit;
    };

    checks.${system}.gen-commit = import ./tests/gen-commit.nix {
      inherit pkgs;
      genCommit = gen-commit;
    };

    nixosConfigurations = {
      ryans-nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./host/configuration.nix
          ./host/hardware-configuration.nix
          ./modules/system/default.nix
          ./modules/system/sof-sdw-ptl-rt721.nix
          ./modules/system/secrets.nix

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
    };
  };
}
