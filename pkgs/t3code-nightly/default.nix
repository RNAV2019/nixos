# T3 Code nightlies are AppImage-only. Get `version` from the latest release tag
# and the hash via `nix store prefetch-file` on the AppImage URL.
{
  appimageTools,
  fetchurl,
}: let
  pname = "t3code-nightly";
  version = "0.1.6-nightly.20261030.3917";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-5OKXOohRi52ANQsv39Gwo2UujiGSDFWiaNnfDxDnfSM=";
  };
  appimageContents = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    # The FHS environment cannot provide a setuid chrome-sandbox.
    extraInstallCommands = ''
      install -Dm644 ${appimageContents}/t3code.desktop \
        $out/share/applications/${pname}.desktop
      install -Dm644 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/t3code.png \
        $out/share/icons/hicolor/512x512/apps/t3code.png

      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun %U' 'Exec=${pname} --no-sandbox %U'
    '';
  }
