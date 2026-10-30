{
  config,
  pkgs,
  helium-browser,
  llm-agents,
  ...
}: let
  agents = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # Ahead of llm-agents until it catches up; the guard drops this once it does.
  claude-code-version = "2.1.310";
  claude-code =
    if pkgs.lib.versionOlder agents.claude-code.version claude-code-version
    then
      agents.claude-code.overrideAttrs {
        version = claude-code-version;
        src = pkgs.fetchurl {
          url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${claude-code-version}/linux-x64/claude";
          hash = "sha256-tzZ2QwrxL5cxanmLg3H4HWQPkKWL3LjzzlaoNbtH31Y=";
        };
      }
    else agents.claude-code;

  # Pinned Web Store CRXes via --load-extension, since policy installs are broken
  # (imputnet/helium#1737); signing key injected to keep IDs. Bump version and hash to update.
  helium-extensions = {
    bitwarden = {
      id = "nngceckbapebfimnlniiiahkandclblb";
      version = "2026.10.0";
      hash = "sha256-8v63/EbSVQvvm2mvHMNYrqJrkKlHZF+d4W7BTZKW72k=";
    };
    better-lyrics = {
      id = "effdbpeggelllpfkjppbokhmmiinhlmg";
      version = "3.0.1";
      hash = "sha256-y6iVlaqsxg8otRGlV5+gW88PIkwHlABzH9Ehn6l3NGM=";
    };
    better-lyrics-shaders = {
      id = "mffpncjphfmkppebdoaehdlnagnlpfai";
      version = "1.5.1";
      hash = "sha256-zizbSfpoBI+Hn+PhHdi4qz/wZH4ZaOCn0e9vlknfYP4=";
    };
  };

  # PDFs open in bionic-reading's bundled PDF.js, so it replaces the PDF Viewer extension.
  helium-extension-dirs =
    pkgs.lib.mapAttrsToList (name: ext: pkgs.fetchCrx (ext // {inherit name;})) helium-extensions
    ++ [pkgs.helium-bionic-reading pkgs.helium-jump-labels];
  # One flag with a comma-separated list: Chromium keeps only the last
  # --load-extension when the switch is repeated.
  helium-extension-flags =
    " --load-extension=" + pkgs.lib.concatStringsSep "," helium-extension-dirs;

  # Drop the wrapper's --disable-background-networking (auto-update stays off via
  # its own flags) and add the extensions.
  helium = (helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
    # Helium with ../pkgs/helium/patches (zen sidebar, command bar, split view, ...),
    # built on the Windows PC; too big for the repo, so it is added to the store by hand.
    version = "0.20.1.1-zen";
    src = pkgs.requireFile {
      name = "helium-zen-0.20.1.1";
      hashMode = "recursive";
      hash = "sha256-2JZ4SHvBbbNZUGIiYmwQj9t3Sf+7vCxoS/7NXpVL0C4=";
      message = ''
        Build Helium 0.20.1.1 with pkgs/helium/patches applied (out/Default on the build
        PC), copy helium, the .pak files, locales/ and the rest of a release dir into a
        directory named helium-zen-0.20.1.1, then run
          nix-store --add-fixed --recursive sha256 helium-zen-0.20.1.1
        and update the hash here.
      '';
    };
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
    extensions = helium-extension-dirs;
    inherit (pkgs) lib;
    stateDir = "${config.home.homeDirectory}/.local/state/theme";
  };

  # nixpkgs wraps Nautilus with GStreamer's base plugins only, so Properties ›
  # Audio/Video says "missing a plug-in" for MP4, MKV and WebM. Good/bad have the
  # demuxers; libav and ugly decode H.264, H.265, AAC and AC-3 far enough for it.
  nautilus = pkgs.nautilus.overrideAttrs (old: {
    buildInputs =
      old.buildInputs
      ++ (with pkgs.gst_all_1; [gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav]);
  });
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

    claude-code
    agents.opencode

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
    # adb over the network to the Chromecast; scrcpy mirrors and drives it.
    android-tools
    scrcpy

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
    # Thumbnails for image clips in the launcher's clipboard history.
    gdk-pixbuf
    # The launcher's Shift+Return on an emoji types it into the focused window.
    wtype

    # The launcher's calculator: maths, units and currency.
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
