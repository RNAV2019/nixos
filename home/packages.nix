{
  pkgs,
  helium-browser,
  llm-agents,
  note-tui,
  ...
}: let
  # Declarative Helium extensions, one list, one mechanism. Helium's
  # policy-driven extension download silently never installs (imputnet/helium
  # #1737), so nothing is installed through enterprise policy here; every
  # extension is instead loaded from a pinned Chrome Web Store CRX via
  # --load-extension below. Each CRX is unpacked at build time and its
  # original signing key is injected into the manifest, which keeps the
  # official extension ID - and therefore profile settings and native
  # messaging origins - intact. To update an extension, bump its version and
  # hash (the build fails loudly until you do).
  helium-extensions = {
    bitwarden = {
      id = "nngceckbapebfimnlniiiahkandclblb"; # Bitwarden Password Manager
      version = "2026.8.0";
      hash = "sha256-0aWULZwjTQM4LamSeZMgVQZMquejLMmxV5QMhjFl1Z8=";
    };
    better-lyrics = {
      id = "effdbpeggelllpfkjppbokhmmiinhlmg"; # Better Lyrics (for YT Music)
      version = "2.3.3";
      hash = "sha256-VvwvtRNhTr3G/4Fb7zU1XL4KtzV/3g2LDxdOPDd3pvI=";
    };
    better-lyrics-shaders = {
      id = "mffpncjphfmkppebdoaehdlnagnlpfai"; # Better Lyrics Shaders
      version = "1.2.0";
      hash = "sha256-RXtMcUYihh/nlVajWAlkonMRBMr/O8KmFUgfaOMS+Ws=";
    };
    pdf-viewer = {
      id = "oemmndcbldboiebfnladdacbdfmadadm"; # PDF Viewer (pdfjs.robwu.nl)
      version = "4.6.129";
      hash = "sha256-NVvF8Y/4b4qbinKU4cmxh6WE0CqMMxGjJp8Wi03hodA=";
    };
  };

  # The extension ID Chromium computes for a key is the first 16 bytes of the
  # key's SHA-256, hex digits mapped to a-p. Searching the CRX3 header for the
  # DER SPKI that hashes to the expected ID recovers the extension's original
  # signing key, whatever proof layout Google's signer used.
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

  # A CRX is a protobuf header followed by a zip of the unpacked extension.
  # Give the fetchurl output a fixed name: a derived store path would
  # otherwise carry "?" and "&" from the URL, which do not survive bash
  # unquoted (an unquoted `if=<path?>` loses its argument entirely under
  # bash 5.3).
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

  # The upstream wrapper passes --disable-background-networking, which also
  # disables the extension updater that policy-forced installs go through, so
  # the managed extensions never download. Auto-update and component update
  # stay off via their own flags.
  helium = (helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      sed -i 's/ --disable-background-networking//' $out/bin/helium
      sed -i 's| "$@"|${helium-extension-flags} "$@"|' $out/bin/helium
    '';
  });

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
    helium
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

    # Editing secrets/secrets.yaml: `sops secrets/secrets.yaml` from the flake
    # root, with SOPS_AGE_KEY_FILE=/etc/nixos-secrets/age.key.
    sops
    age
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
