{
  description = "Ryan's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium-browser = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Sonora music client (sonorahq.org); prebuilt release binary on x86_64-linux.
    sonora = {
      url = "github:sonorahq/sonora";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Quick Share + AirDrop daemon (nearbyd) and the omdrop-owl AWDL backend.
    # A local path only because the repo has no remote yet, so this flake evaluates on this
    # machine alone. Once it is pushed, use its github: URL and develop against the checkout
    # with `--override-input nearby path:/home/ryan/Projects/nearby`.
    nearby = {
      url = "path:/home/ryan/Projects/nearby";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Decryption key lives at /etc/nixos-secrets/age.key, never in this repo.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    helium-browser,
    llm-agents,
    sonora,
    helix-steel,
    note-tui,
    fenix,
    sops-nix,
    nearby,
    ...
  }: let
    system = "x86_64-linux";
    inherit (nixpkgs) lib;
    pkgs = import nixpkgs {
      inherit system;
      overlays = [self.overlays.default];
    };
    # Every derivation in ./pkgs, as built by the overlay.
    ownPackages = lib.filterAttrs (_: lib.isDerivation) (lib.intersectAttrs (import ./pkgs pkgs pkgs) pkgs);
  in {
    # ./pkgs, plus my own projects that live in their own flakes.
    overlays.default = lib.composeManyExtensions [
      (import ./pkgs)
      (final: _prev: {
        note-tui = note-tui.packages.${final.stdenv.hostPlatform.system}.default;
      })
    ];

    packages.${system} =
      ownPackages
      // {
        inherit (pkgs) note-tui;
        default = pkgs.gen-commit;
      };

    formatter.${system} = pkgs.alejandra;

    checks.${system} = {
      gen-commit = pkgs.callPackage ./pkgs/gen-commit/tests {};
      ical-agenda = pkgs.callPackage ./pkgs/ical-agenda/tests {};
      phone-bridge = pkgs.callPackage ./pkgs/phone-bridge/tests {};

      # NixOS VM: wifi.nix on iwd against hostapd/RADIUS on mac80211_hwsim.
      wifi-iwd = import ./tests/wifi-iwd.nix {inherit pkgs;};

      # NixOS VM: the shell's polkit agent against a real polkitd and PAM, in a session of its own.
      polkit-agent = import ./tests/polkit-agent.nix {inherit pkgs;};

      # qmlformat reads home/quickshell/.qmlformat.ini; any file it would change fails.
      quickshell-qmlformat =
        pkgs.runCommand "quickshell-qmlformat" {
          nativeBuildInputs = [pkgs.qt6Packages.qtdeclarative];
          LANG = "C.UTF-8";
        } ''
          cd ${./home/quickshell}
          status=0
          while IFS= read -r -d "" file; do
            if ! qmlformat "$file" | diff -u "$file" - >&2; then
              echo "needs qmlformat: $file" >&2
              status=1
            fi
          done < <(find . -type f -name '*.qml' -print0)
          [ "$status" -eq 0 ] && touch "$out"
        '';

      nix-format =
        pkgs.runCommand "nix-format" {
          nativeBuildInputs = [pkgs.alejandra];
        } ''
          alejandra --check ${self} && touch "$out"
        '';
    };

    # Named after each hostname so a bare `nixos-rebuild --flake ~/nixos` picks
    # the right one. Per-machine config lives in hosts/<name>.
    nixosConfigurations = let
      # `user` owns the session and the home-manager config; `repoDir` is this checkout,
      # which out-of-store links (quickshell, profile.jpg) and edit-secrets point into.
      mkHost = {
        hostName,
        user,
      }: let
        args = {
          inherit helium-browser llm-agents sonora helix-steel fenix user;
          repoDir = "/home/${user}/nixos";
        };
      in
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/${hostName}
            ./modules/system
            {networking.hostName = hostName;}

            {nixpkgs.overlays = [self.overlays.default];}

            sops-nix.nixosModules.sops
            nearby.nixosModules.default

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Preserve unmanaged files during activation.
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${user} = import ./home/default.nix;
              home-manager.extraSpecialArgs = args;
            }
          ];
          specialArgs = args;
        };
    in {
      ryans-nixos = mkHost {
        hostName = "ryans-nixos";
        user = "ryan";
      };
    };
  };
}
