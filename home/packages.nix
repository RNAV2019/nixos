{
  config,
  pkgs,
  helium-browser,
  llm-agents,
  ...
}: let
  # Pinned Web Store CRXes via --load-extension, since policy installs are broken
  # (imputnet/helium#1737); signing key injected to keep IDs. Bump version and hash to update.
  helium-extensions = {
    bitwarden = {
      id = "nngceckbapebfimnlniiiahkandclblb";
      version = "2026.8.0";
      hash = "sha256-8v63/EbSVQvvm2mvHMNYrqJrkKlHZF+d4W7BTZKW72k=";
    };
    better-lyrics = {
      id = "effdbpeggelllpfkjppbokhmmiinhlmg";
      version = "2.3.3";
      hash = "sha256-hPeaaZ4l5oTahB5Ad2eMI+9DXNqcCRI+ocW5pYk1hk4=";
    };
    better-lyrics-shaders = {
      id = "mffpncjphfmkppebdoaehdlnagnlpfai";
      version = "1.2.0";
      hash = "sha256-WES3hJ0iXlYTkf3uzWIhtBwZaVJh5PX6xgTGmPbK4Ko=";
    };
  };

  # PDFs open in bionic-reading's bundled PDF.js, so it replaces the PDF Viewer extension.
  helium-extension-dirs =
    pkgs.lib.mapAttrsToList (name: ext: pkgs.fetchCrx (ext // {inherit name;})) helium-extensions
    ++ [pkgs.helium-bionic-reading];
  # One flag with a comma-separated list: Chromium keeps only the last
  # --load-extension when the switch is repeated.
  helium-extension-flags =
    " --load-extension=" + pkgs.lib.concatStringsSep "," helium-extension-dirs;

  # Drop the wrapper's --disable-background-networking (auto-update stays off via
  # its own flags) and add the extensions.
  helium = (helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        sed -i 's/ --disable-background-networking//' $out/bin/helium
        sed -i 's| "$@"|${helium-extension-flags} "$@"|' $out/bin/helium
      '';
  });

  # The same Helium, launched so that it follows the desktop theme live; see themes/helium.nix.
  helium-themed = import ./themes/helium.nix {
    inherit pkgs helium;
    inherit (pkgs) lib;
    stateDir = "${config.home.homeDirectory}/.local/state/theme";
  };
in {
  # Rose Pine is the default; the other themes swap the GTK and icon theme at runtime.
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
    enable = true;
    gtk.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # Kvantum for Qt 5/6, in the active theme's colours.
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  # kvantum.kvconfig, which picks the theme, is linked to the active theme in theme.nix.
  xdg.configFile = {
    "Kvantum/rose-pine-love".source = "${pkgs.rose-pine-kvantum}/share/Kvantum/themes/rose-pine-love";
  };

  # Rose Pine defaults; theme.nix and theme-switch overwrite them with the active theme.
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
    helium-themed
    firefox

    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode

    tree
    upower
    speedtest-cli
    trash-cli

    ghostty
    kitty

    nautilus
    # The Nearby file picker reads image dimensions for its preview from file(1).
    file

    localsend
    tigervnc

    awww
    anki

    blanket

    brightnessctl
    playerctl
    pavucontrol
    mpv

    # notify-send; the shell's NotificationStore is the server.
    libnotify

    # dlopen dependencies for locally built Wayland apps.
    wayland
    libxkbcommon

    wl-clipboard
    cliphist

    # The launcher's '=' mode: maths, units and currency.
    libqalculate

    # GTK portal for libadwaita dark mode.
    xdg-desktop-portal-gtk

    networkmanagerapplet

    grimblast
    # Used directly by the lock screen; grimblast's PNG compression is too slow.
    grim
    # Screen recorder; chosen over wf-recorder for --no-cursor and named audio devices.
    wl-screenrec
    slurp
    hyprpicker

    fd
    ripgrep
    eza
    tokei
    silicon
    glow
    just
    hyperfine
    unzip

    nitch
    fetch

    cloudflared

    sops
    age
    # Defined in modules/system/default.nix.
    rustToolchain
    nodejs_latest
    # Stock nixpkgs build (v1.32.0) for binary-cache hits; no source rebuild.
    aube
    jq
    openssl
    jdk21
    ghc
    gcc
    godot
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
    # Typst notes TUI; previews via tinymist and Helium (see editors.nix).
    note-tui
    # Stock nixpkgs build for binary-cache hits; no Go compile.
    stripe-cli
    nixd
    alejandra
    gnumake
    espeak-ng
  ];
}
