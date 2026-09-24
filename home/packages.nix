{
  config,
  pkgs,
  helium-browser,
  llm-agents,
  note-tui,
  ...
}: let
  # Pinned Web Store CRXes via --load-extension, since policy installs are broken
  # (imputnet/helium#1737); signing key injected to keep IDs. Bump version and hash to update.
  helium-extensions = {
    bitwarden = {
      id = "nngceckbapebfimnlniiiahkandclblb";
      version = "2026.8.0";
      hash = "sha256-0aWULZwjTQM4LamSeZMgVQZMquejLMmxV5QMhjFl1Z8=";
    };
    better-lyrics = {
      id = "effdbpeggelllpfkjppbokhmmiinhlmg";
      version = "2.3.3";
      hash = "sha256-ozei1UtnBBP2v49I8DTmrACnNvlj7ay0N4P0ycfOwyM=";
    };
    better-lyrics-shaders = {
      id = "mffpncjphfmkppebdoaehdlnagnlpfai";
      version = "1.2.0";
      hash = "sha256-h6zGfE7b1d+SInTZU9gLomS0c3uMepufh67F9sjRG4w=";
    };
    pdf-viewer = {
      id = "oemmndcbldboiebfnladdacbdfmadadm";
      version = "4.6.129";
      hash = "sha256-NVvF8Y/4b4qbinKU4cmxh6WE0CqMMxGjJp8Wi03hodA=";
    };
  };

  # Finds the DER key in the CRX3 header whose SHA-256 (hex mapped to a-p) matches
  # the extension ID, and writes it into manifest.json.
  crx-key-inject = pkgs.writers.writePython3Bin "crx-key-inject" {} ''
    import base64
    import hashlib
    import json
    import struct
    import sys

    crx_path, expected_id, out_dir = sys.argv[1:4]


    def to_id(der):
        digest = hashlib.sha256(der).hexdigest()[:32]
        table = "abcdefghijklmnopabcdefghijklmnop"
        return "".join(table[int(c, 16)] for c in digest)


    buf = open(crx_path, "rb").read()
    assert buf[:4] == b"Cr24", "not a CRX"
    assert struct.unpack("<I", buf[4:8])[0] == 3, "not a CRX3"
    hlen = struct.unpack("<I", buf[8:12])[0]
    header = buf[12:12 + hlen]

    key = None
    for i in range(len(header)):
        if header[i] != 0x30:  # DER SEQUENCE
            continue
        b = header[i + 1]
        if b < 0x80:
            length = 2 + b
        elif b & 0x7F in (1, 2):
            n = b & 0x7F
            length = 2 + n + int.from_bytes(header[i + 2:i + 2 + n], "big")
        else:
            continue
        if length < 32 or i + length > len(header):
            continue
        candidate = header[i:i + length]
        if to_id(candidate) == expected_id:
            key = candidate
            break
    if key is None:
        sys.exit(f"no signing key producing ID {expected_id} found in {crx_path}")

    manifest_path = out_dir + "/manifest.json"
    manifest = json.load(open(manifest_path))
    manifest["key"] = base64.b64encode(key).decode()
    assert to_id(base64.b64decode(manifest["key"])) == expected_id
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
  '';

  # A CRX is a protobuf header followed by a zip. The fetchurl name keeps the
  # URL's "?" and "&" out of the store path.
  unpack-helium-extension = name: ext:
    pkgs.runCommand "helium-extension-${name}" {} ''
      mkdir -p $out
      crx="${
        pkgs.fetchurl {
          name = "${name}-${ext.version}.crx";
          url = "https://clients2.google.com/service/update2/crx?response=redirect&os=linux&arch=x64&os_arch=x86-64&nacl_arch=x86-64&prod=chromiumcrx&prodchannel=unknown&prodversion=152.0.0.0&acceptformat=crx2,crx3&x=id%3D${ext.id}%26uc";
          hash = ext.hash;
        }
      }"
      header_len=$(od -A n -t u4 -j 8 -N 4 "$crx" | tr -d ' ')
      dd if="$crx" of=payload.zip bs=1 skip=$((12 + header_len)) status=none
      ${pkgs.unzip}/bin/unzip -q payload.zip -d $out
      ${crx-key-inject}/bin/crx-key-inject "$crx" ${ext.id} $out
    '';

  helium-extension-dirs = pkgs.lib.mapAttrsToList unpack-helium-extension helium-extensions;
  # One flag with a comma-separated list: Chromium keeps only the last
  # --load-extension when the switch is repeated.
  helium-extension-flags =
    " --load-extension=" + pkgs.lib.concatStringsSep "," helium-extension-dirs;

  # Drop the wrapper's --disable-background-networking (auto-update stays off via
  # its own flags) and add the extensions.
  helium = (helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      sed -i 's/ --disable-background-networking//' $out/bin/helium
      # Helium's Accept-Language reduction trips Akamai bot checks on hm.com,
      # next.co.uk, etc. (imputnet/helium#1917); disable it.
      sed -i 's| "$@"| --disable-features=ReduceAcceptLanguage${helium-extension-flags} "$@"|' $out/bin/helium
    '';
  });

  # The same Helium, launched so that it follows the desktop theme live; see themes/helium.nix.
  helium-themed = import ./themes/helium.nix {
    inherit pkgs helium;
    inherit (pkgs) lib;
    stateDir = "${config.home.homeDirectory}/.local/state/theme";
  };

  # Dropped from nixpkgs in 2026-08; vendored with only the GTK3/GTK4 assets.
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
  # Rose Pine is the default; the dark theme swaps the GTK and icon theme at runtime.
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

    localsend

    awww

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

    nitch
    fetch

    cloudflared

    sops
    age
    # Defined in modules/system/default.nix.
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
      # cargoHash is baked in before overrideAttrs, so replace cargoDeps directly.
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) src;
        hash = "sha256-Pj7TBxzaCJMP3AcDWMlG1iE+nlSzx0NjU6aFVV5kGrc=";
      };
      # Lifecycle-script tests run `node`.
      nativeCheckInputs = prev.nativeCheckInputs ++ [pkgs.nodejs];
      checkFlags = [
        # Upstream's .cargo/config.toml serialises tests, but the cargo hook replaces it.
        "--test-threads=1"
        # Needs a release-only corpus missing from the source tarball.
        "--skip=commands::add_supply_chain::tests::bundled_corpus_detects_common_package_typo"
        # Execs /bin/echo, absent in the sandbox.
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
    # Typst notes TUI; previews via tinymist and Helium (see editors.nix).
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
    nixd
    alejandra
    gnumake
    espeak-ng
  ];
}
