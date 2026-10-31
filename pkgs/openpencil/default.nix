# OpenPencil, the local design editor that replaced Penpot. Get `version` from the latest
# stable release tag and the hash via `nix store prefetch-file` on the AppImage URL. Its MCP
# server is wired up in home/claude.nix.
{
  appimageTools,
  fetchurl,
  writeShellScriptBin,
  openpencil-cli,
}: let
  pname = "openpencil";
  version = "0.16.0";
  src = fetchurl {
    url = "https://github.com/open-pencil/open-pencil/releases/download/v${version}/OpenPencil_${version}_amd64.AppImage";
    hash = "sha256-p9iTrDU2fI6gALAIkBNs5YYaE78ldLRHYPd4Sc/fd6I=";
  };
  appimageContents = appimageTools.extract {inherit pname version src;};

  # The app spawns its MCP bridge, openpencil-mcp-http, from PATH. Node must not see the
  # AppImage's LD_LIBRARY_PATH: its bundled libnghttp2 lacks symbols Node links against.
  mcpBridge = writeShellScriptBin "openpencil-mcp-http" ''
    unset LD_LIBRARY_PATH
    exec ${openpencil-cli}/bin/openpencil-mcp-http "$@"
  '';
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraPkgs = _: [mcpBridge];

    # `openpencil` is the CLI's name (pkgs/openpencil/cli), so the app gets its own.
    extraInstallCommands = ''
      mv $out/bin/${pname} $out/bin/openpencil-desktop

      install -Dm644 ${appimageContents}/OpenPencil.desktop \
        $out/share/applications/${pname}.desktop
      for size in 32x32 128x128; do
        install -Dm644 ${appimageContents}/usr/share/icons/hicolor/$size/apps/OpenPencil.png \
          $out/share/icons/hicolor/$size/apps/OpenPencil.png
      done
      install -Dm644 ${appimageContents}/usr/share/icons/hicolor/256x256@2/apps/OpenPencil.png \
        $out/share/icons/hicolor/256x256@2/apps/OpenPencil.png

      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=OpenPencil %U' 'Exec=openpencil-desktop %U' \
        --replace-fail 'Categories=' 'Categories=Graphics;VectorGraphics;'
    '';
  }
