# Apple's SF Pro, the shell's UI face (home/quickshell/Commons/Theme.qml). Only the static
# Text and Display cuts are installed: Qt's FreeType engine draws a variable font's default
# instance whatever weight is asked for, so the variable SF-Pro.ttf would lose the weights.
{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "sf-pro";
  version = "0-unstable-8bfea09";
  src = fetchFromGitHub {
    owner = "sahibjotsaggu";
    repo = "San-Francisco-Pro-Fonts";
    rev = "8bfea09aa6f1139479f80358b2e1e5c6dc991a58";
    hash = "sha256-mAXExj8n8gFHq19HfGy4UOJYKVGPYgarGd/04kUIqX4=";
  };
  installPhase = ''
    mkdir -p $out/share/fonts/opentype
    cp SF-Pro-Text-*.otf SF-Pro-Display-*.otf $out/share/fonts/opentype/
  '';
}
