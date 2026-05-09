{ pkgs, helium-browser, llm-agents, ... }:
{
  home.packages = with pkgs; [
    # Browsers
    helium-browser.packages.${pkgs.system}.default
    firefox

    # LLM agents
    llm-agents.packages.${pkgs.system}.claude-code
    llm-agents.packages.${pkgs.system}.opencode

    # TUI system tools
    (pkgs.rustPlatform.buildRustPackage {
      pname   = "wlctl";
      version = "unstable";
      src = pkgs.fetchFromGitHub {
        owner = "aashish-thapa";
        repo  = "wlctl";
        rev   = "main";
        hash  = "sha256-94WfzaBBjzGIkgHlco8T3iQqsjyAWxG+dw0lAfsKsfQ=";
      };
      cargoHash = "sha256-JzYrQICduP1lgjfwGJlt6aUJfe5jG1wRVYbx5A8wtXg=";
    })
    bluetui
    wiremix
    wlogout

    # File manager
    nautilus

    # Wallpaper
    awww

    # Ambient Sounds
    blanket

    # PDF viewer
    zathura

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
    grimblast

    # Terminal Utils
    bat
    fd
    ripgrep
    fzf
    eza
    zoxide
    tokei     # Line counter
    silicon   # Code screenshot generator
    glow      # Render markdown in terminal
    tealdeer  # TLDR man pages
    btop
    just      # Command runner (better than make)
    hyperfine

    # Git
    lazygit
    delta
    gh

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
    nixd      # Nix language server
    alejandra # Nix formatter
    gnumake   # Make
  ];
}
