{
	description = "Ryan's NixOS Configuration";

	# nixConfig = {
	# 	# Binary cache for llm-agents and vicinae
	# 	extra-substituters = [
	# 		"https://numtide.cachix.org"
	# 		"https://vicinae.cachix.org"
	# 	];

	# 	extra-trusted-public-keys = [
	# 		"numtide.cachix.org-1:2ps1kLzmB3zAYxSBGFBaKi93WqWaS/qfErxj9kRfFrA="
	# 		"vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
	# 	];
	# };
	
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

		# Vicinae
		vicinae = {
			url = "github:vicinaehq/vicinae";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	# NixOS flake configuration for hyprland with home-manager
	outputs = inputs@{ nixpkgs, home-manager, hyprland, helium-browser, llm-agents, vicinae, ... }: {
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
						home-manager.extraSpecialArgs = { inherit hyprland helium-browser llm-agents vicinae; };
					}
				];
				specialArgs = { inherit hyprland helium-browser llm-agents vicinae; };
			};
		};		
	};
}
