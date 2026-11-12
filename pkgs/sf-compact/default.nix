# Apple's SF Compact, the shell's UI face (home/quickshell/Commons/Theme.qml). Apple's DMG is
# the only source: it holds a .pkg whose Payload is a cpio, all of which 7zz unpacks. Only the
# static Text, Display and Rounded cuts are installed (Rounded is the lock screen's clock): Qt's
# FreeType engine draws a variable font's default instance whatever weight is asked for, so the
# variable SF-Compact.ttf would lose the weights.
#
# Apple replaces the file at this URL in place when it ships a new version, so the hash goes
# stale then: prefetch it again (nix store prefetch-file) and bump `version`.
{
  stdenvNoCC,
  fetchurl,
  _7zz,
}:
stdenvNoCC.mkDerivation {
  pname = "sf-compact";
  version = "2026-11-04";
  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg";
    hash = "sha256-byQRcYdqhBdNS5m69Gm6+z+OJFTOoSPYULM/H7D3D18=";
  };
  nativeBuildInputs = [_7zz];
  unpackPhase = ''
    runHook preUnpack
    7zz x -y $src -odmg >/dev/null
    7zz x -y "$(find dmg -name SFCompactFonts.pkg)" -opkg >/dev/null
    7zz x -y pkg/SFCompactFontsPackage.pkg/Payload -opayload >/dev/null
    7zz x -y 'payload/Payload~' -ofonts >/dev/null
    runHook postUnpack
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/opentype
    find fonts \( -name 'SF-Compact-Text-*.otf' -o -name 'SF-Compact-Display-*.otf' \
      -o -name 'SF-Compact-Rounded-*.otf' \) \
      -exec cp {} $out/share/fonts/opentype/ \;
    runHook postInstall
  '';
}
