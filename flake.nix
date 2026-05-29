{
  description = "Ryan's NixOS Configuration";

  inputs = {
    # Main package repository - unstable branch
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home manager for user environment and dotfiles
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland flake
    hyprland.url = "github:hyprwm/Hyprland";

    # Helium browser
    helium-browser = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LLM agents
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  # NixOS flake configuration for hyprland with home-manager
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
            home-manager.users.ryan = import ./home/default.nix;
            home-manager.extraSpecialArgs = {inherit hyprland helium-browser llm-agents;};
          }
        ];
        specialArgs = {inherit hyprland helium-browser llm-agents;};
      };
    };
  };
}
