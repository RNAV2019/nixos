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

  # Qt follows GTK theme
  qt = {
    enable = true;
    platformTheme.name = "gtk";
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

    # Terminal
    ghostty
    kitty

    # File manager
    nautilus

    # File sharing
    localsend

    # Wallpaper
    awww

    # Ambient Sounds
    blanket

    # Controls
    brightnessctl
    playerctl
    pavucontrol

    # Clipboard
    wl-clipboard
    cliphist

    # Networking
    networkmanagerapplet

    # Notification daemon
    mako

    # Volume/brightness on-Screen display
    swayosd

    # Screenshot tool
    hyprshot

    # Terminal Utils
    bat
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
    jdk21
    ghc
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
    nixd # Nix language server
    alejandra # Nix formatter
    gnumake # Make
  ];
}
