{
  pkgs,
  helium-browser,
  llm-agents,
  ...
}: {
  # GTK dark mode
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
    gtk4.theme = null; # use libadwaita color-scheme instead of forcing GTK4 theme
  };

  # System-wide cursor (GTK + Wayland + X11)
  home.pointerCursor = {
    gtk.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # Qt theming via Kvantum (Rose Pine, Qt5 + Qt6)
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  # Rose Pine "love" Kvantum theme for Qt apps
  xdg.configFile = {
    "Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=rose-pine-love
    '';
    "Kvantum/rose-pine-love".source = "${pkgs.rose-pine-kvantum}/share/Kvantum/themes/rose-pine-love";
  };

  # GNOME color scheme for libadwaita/GTK4 apps
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = "rose-pine";
      gtk-theme = "rose-pine";
      cursor-theme = "Bibata-Modern-Classic";
      cursor-size = 24;
    };
  };

  # Keep XDG user dirs session variables behaviour
  xdg.userDirs.setSessionVariables = true;

  home.packages = with pkgs; [
    # Browsers
    helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    firefox

    # LLM agents
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode

    # TUI system tools
    (pkgs.rustPlatform.buildRustPackage {
      pname = "wlctl";
      version = "unstable";
      src = pkgs.fetchFromGitHub {
        owner = "aashish-thapa";
        repo = "wlctl";
        rev = "4bfb8c28655cc2a7e0e67bfe3d5d76e8d632b1b6";
        hash = "sha256-94WfzaBBjzGIkgHlco8T3iQqsjyAWxG+dw0lAfsKsfQ=";
      };
      cargoHash = "sha256-JzYrQICduP1lgjfwGJlt6aUJfe5jG1wRVYbx5A8wtXg=";
    })
    bluetui
    wiremix
    wlogout
    tree
    upower
    speedtest-cli

    # Terminal
    ghostty
    kitty

    # File manager
    nautilus

    # File sharing
    localsend

    # Wallpaper
    awww

    # Screen recording
    openscreen

    # Ambient Sounds
    blanket

    # Controls
    brightnessctl
    playerctl
    pavucontrol
    mpv

    # Wayland runtime libs (needed by locally-built Rust apps using dlopen, e.g. mycelium)
    wayland
    libxkbcommon

    # Clipboard
    wl-clipboard
    cliphist

    # XDG portal GTK backend (prefer-dark for libadwaita apps)
    xdg-desktop-portal-gtk

    # Networking
    networkmanagerapplet

    # Notification daemon
    mako

    # Volume/brightness on-Screen display
    swayosd

    # Screenshot tools
    grimblast
    hyprpicker

    # Terminal Utils
    # bat is configured via programs.bat in shell.nix (Rose Pine theme)
    fd
    ripgrep
    eza
    tokei # Line counter
    silicon # Code screenshot generator
    glow # Render markdown in terminal
    just # Command runner (better than make)
    hyperfine

    # Fetcher
    nitch

    # Development Utils
    rustup
    nodejs_24
    bun
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
    gnumake # Make
    espeak-ng
  ];
}
