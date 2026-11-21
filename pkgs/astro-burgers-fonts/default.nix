# Fonts the Astro Burgers game uses: Pixeloid (OFL) and ArcadeClassic. Upstream ships the
# Pixeloid faces as both .ttf and .otf, but both are TrueType with the same names, so only
# the .ttf copies are kept to avoid duplicate families in fontconfig.
{stdenvNoCC}:
stdenvNoCC.mkDerivation {
  pname = "astro-burgers-fonts";
  version = "0";
  src = ./fonts;
  installPhase = ''
    mkdir -p $out/share/fonts/truetype
    cp *.ttf *.TTF $out/share/fonts/truetype/
  '';
}
