{
  pkgs,
  helium-browser,
  llm-agents,
  ...
}: {
  gtk = {
    enable = true;
    theme = {
      name = "rose-pine";
      package = pkgs.rose-pine-gtk-theme;
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

    cloudflared
    rustup
    nodejs_24
    bun
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
    # Pinned newer than nixpkgs (1.37.2)
    (stripe-cli.overrideAttrs (finalAttrs: _prev: {
      version = "1.43.7";
      src = pkgs.fetchFromGitHub {
        owner = "stripe";
        repo = "stripe-cli";
        tag = "v${finalAttrs.version}";
        hash = "sha256-2rjjMbghE8S496gFGBY7XJOrmQXC7LflKHquBoqDQgY=";
      };
      vendorHash = "sha256-RYbwc7QuYSwUX42AM1YSOx+JvsPf2aLScX+2XN0SeYQ=";
      doCheck = false;
    }))
    nixd # Nix language server
    alejandra # Nix formatter
    gnumake
    espeak-ng
  ];
}
