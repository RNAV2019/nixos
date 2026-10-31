# Families the OpenPencil designs use that nixpkgs lacks or ships only as multi-axis variable
# fonts. Static faces are cut from Google Fonts' variable fonts (instance.py) so the design
# tools see each weight as its own face.
{
  lib,
  runCommand,
  fetchurl,
  python3,
}: let
  googleFont = dir: file: hash:
    fetchurl {
      name = "${builtins.head (lib.splitString "[" file)}.ttf";
      url = "https://raw.githubusercontent.com/google/fonts/00a38a53f92aef923b9353f40128e8f4552ddae4/ofl/${dir}/${lib.replaceStrings ["[" "]"] ["%5B" "%5D"] file}";
      inherit hash;
    };
  # family, source font, upright or italic, weights.
  faces = [
    ["Inter Tight" (googleFont "intertight" "InterTight[wght].ttf" "sha256-uBtz3LZN88IwyrreffbFdzv4YyM/JMnuUQh1GfH4i28=") "upright" [400 500 600 700]]
    ["Space Grotesk" (googleFont "spacegrotesk" "SpaceGrotesk[wght].ttf" "sha256-rK1t4fyTQ29cDx9BN3Ue8E8a6jBj5wNlNZcP/PvXn3I=") "upright" [400 500 600 700]]
    ["Fraunces" (googleFont "fraunces" "Fraunces[SOFT,WONK,opsz,wght].ttf" "sha256-F3/2wPFOVVCjxiQkfNEYlhHU62XQALFJRMY9lnlYq7s=") "upright" [300 400 600]]
    ["Fraunces" (googleFont "fraunces" "Fraunces-Italic[SOFT,WONK,opsz,wght].ttf" "sha256-skRIxDcC+sTuhWeB1GGg37qNjllLbo4ZAjS3X+0sDgE=") "italic" [300 400]]
  ];
  cut = face: let
    family = builtins.elemAt face 0;
    src = builtins.elemAt face 1;
    slant = builtins.elemAt face 2;
  in
    lib.concatMapStrings (w: ''
      python3 ${./instance.py} ${src} "${family}" ${toString w} ${slant} \
        "$out/share/fonts/truetype/${lib.replaceStrings [" "] [""] family}-${slant}-${toString w}.ttf"
    '')
    (builtins.elemAt face 3);
in
  runCommand "design-fonts" {
    nativeBuildInputs = [(python3.withPackages (ps: [ps.fonttools]))];
  } ''
    mkdir -p $out/share/fonts/truetype
    ${lib.concatMapStrings cut faces}
  ''
