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
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    hyprland,
    helium-browser,
    llm-agents,
    ...
  }: {
    nixosConfigurations = {
      ryans-nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./host/configuration.nix
          ./host/hardware-configuration.nix
          ./modules/system/default.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Preserve unmanaged files during activation.
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.ryan = import ./home/default.nix;
            home-manager.extraSpecialArgs = {inherit hyprland helium-browser llm-agents;};
          }
        ];
        specialArgs = {inherit hyprland helium-browser llm-agents;};
      };
    };
  };
}
