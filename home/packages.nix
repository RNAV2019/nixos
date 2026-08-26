{
  pkgs,
  helium-browser,
  llm-agents,
  note-tui,
  ...
}: let
  # Dropped from nixpkgs in 2026-08 along with its GTK2 murrine dependency.
  # Only the GTK3/GTK4 assets are used here, so it is vendored without the
  # GTK2 engines the old derivation pulled in.
  rose-pine-gtk-theme = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rose-pine-gtk-theme";
    version = "2.2.0";

    src = pkgs.fetchFromGitHub {
      owner = "rose-pine";
      repo = "gtk";
      tag = "v${finalAttrs.version}";
      hash = "sha256-vCWs+TOVURl18EdbJr5QAHfB+JX9lYJ3TPO6IklKeFE=";
    };

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      for n in rose-pine rose-pine-dawn rose-pine-moon; do
        mkdir -p "$out/share/themes/$n/gtk-4.0"
        cp -r "$src/gtk3/$n-gtk"/* "$out/share/themes/$n"
        cp -r "$src/gtk4/$n.css" "$out/share/themes/$n/gtk-4.0/gtk.css"
      done

      runHook postInstall
    '';

    meta.description = "Rosé Pine theme for GTK";
  });
in {
  gtk = {
    enable = true;
    theme = {
      name = "rose-pine";
      package = rose-pine-gtk-theme;
    };
    iconTheme = {
      name = "rose-pine";
      package = pkgs.rose-pine-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.theme = null; # Let libadwaita control GTK 4.
  };

  # Cursor across GTK, Wayland, and X11.
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # Rose Pine via Kvantum for Qt 5/6.
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  xdg.configFile = {
    "Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=rose-pine-love
    '';
    "Kvantum/rose-pine-love".source = "${pkgs.rose-pine-kvantum}/share/Kvantum/themes/rose-pine-love";
  };

  # libadwaita/GTK 4 color scheme.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = "rose-pine";
      gtk-theme = "rose-pine";
      cursor-theme = "Bibata-Modern-Classic";
      cursor-size = 24;
    };
  };

  xdg.userDirs.setSessionVariables = true;

  home.packages = with pkgs; [
    helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    firefox

    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode

    tree
    upower
    speedtest-cli

    ghostty
    kitty

    nautilus

    localsend

    awww

    blanket

    brightnessctl
    playerctl
    pavucontrol
    mpv

    # dlopen dependencies for locally built Wayland apps.
    wayland
    libxkbcommon

    wl-clipboard
    cliphist

    # GTK portal for libadwaita dark mode.
    xdg-desktop-portal-gtk

    networkmanagerapplet

    grimblast
    hyprpicker

    fd
    ripgrep
    eza
    tokei # Line counter
    silicon # Code screenshot generator
    glow # Render markdown in terminal
    just # Command runner
    hyperfine

    nitch
    fetch

    cloudflared
    # cargo/rustc/clippy/rustfmt/rust-src/rust-analyzer, all one stable
    # release. Defined in modules/system/default.nix.
    rustToolchain
    nodejs_latest
    # Pinned newer than nixpkgs (1.32.0)
    (aube.overrideAttrs (finalAttrs: prev: {
      version = "1.41.0";
      src = pkgs.fetchFromGitHub {
        owner = "endevco";
        repo = "aube";
        tag = "v${finalAttrs.version}";
        hash = "sha256-CtqKNNKj4QUz6nZU/PVL/b8nnmBh6Lahj+ngUl34iVg=";
      };
      # buildRustPackage bakes cargoHash into the vendor derivation before
      # overrideAttrs runs, so the vendored deps have to be replaced directly.
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) src;
        hash = "sha256-Pj7TBxzaCJMP3AcDWMlG1iE+nlSzx0NjU6aFVV5kGrc=";
      };
      # The lifecycle-script tests run `node`, which is not otherwise in the
      # build sandbox.
      nativeCheckInputs = prev.nativeCheckInputs ++ [pkgs.nodejs];
      checkFlags = [
        # Upstream's .cargo/config.toml sets RUST_TEST_THREADS=1 because the
        # aube-util killswitch tests mutate process env; the cargo setup hook
        # replaces that config, so the serialization has to be restored here.
        "--test-threads=1"
        # Wants the release-only generated popularity corpus; the source
        # tarball ships without it, so the lookup returns nothing.
        "--skip=commands::add_supply_chain::tests::bundled_corpus_detects_common_package_typo"
        # Execs /bin/echo, which does not exist in the Nix build sandbox.
        "--skip=commands::exec::tests::bin_command_executes_native_target_behind_generated_shim"
      ];
    }))
    jq
    openssl
    jdk21
    ghc
    gcc
    cabal-install
    stack
    haskellPackages.haskell-language-server
    go
    typescript-language-server
    jdt-language-server
    vscode-langservers-extracted
    tailwindcss-language-server
    basedpyright
    haskellPackages.fourmolu
    texlab
    tectonic
    typst
    tinymist
    # Typst notes TUI. Its live preview needs typst/tinymist above and the
    # helium launcher, and reads the tinymist data-plane host set in editors.nix.
    note-tui.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Pinned newer than nixpkgs (1.43.2)
    (stripe-cli.overrideAttrs (finalAttrs: _prev: {
      version = "1.50.4";
      src = pkgs.fetchFromGitHub {
        owner = "stripe";
        repo = "stripe-cli";
        tag = "v${finalAttrs.version}";
        hash = "sha256-PEhVz8vKhnaCAfFeDovp3pTV50UzPzDLygZtUUeaStA=";
      };
      vendorHash = "sha256-ab3um1ewUzTUGUlIsm8ed8xtDKulmXiRN+HJK2wP2h8=";
      doCheck = false;
    }))
    nixd # Nix language server
    alejandra # Nix formatter
    gnumake
    espeak-ng
  ];
}
