# T3 Code ships AppImages only. Get `version` from the latest stable release tag
# (not a nightly) and the hash via `nix store prefetch-file` on the AppImage URL.
{
  appimageTools,
  fetchurl,
}: let
  pname = "t3code";
  version = "0.1.5";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-kz/53ExlCnWqQIfJjyrmxlQMIz8OL+sy6/+VCwm+hJ0=";
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
