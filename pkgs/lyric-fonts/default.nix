# The display faces the lyric stage sets words in (home/quickshell/Lyrics), each named by a
# Theme.lyric*Font token. All are single static fonts from Google Fonts, under the OFL; a face
# that is not installed falls back to the shell's own.
{
  lib,
  runCommand,
  fetchurl,
}: let
  googleFont = licence: dir: file: hash:
    fetchurl {
      name = file;
      url = "https://raw.githubusercontent.com/google/fonts/00a38a53f92aef923b9353f40128e8f4552ddae4/${licence}/${dir}/${file}";
      inherit hash;
    };
  fonts = [
    (googleFont "ofl" "anton" "Anton-Regular.ttf" "sha256-pLo6kjUOuwMdoMtHYwrEnrJlCCyhvARQRC9Kg6uUfKs=")
    (googleFont "ofl" "archivoblack" "ArchivoBlack-Regular.ttf" "sha256-3ZqJoBm0hJ9mq3VFX+e9+TExEELLsPD5eswGFTlwMYA=")
    (googleFont "ofl" "dmserifdisplay" "DMSerifDisplay-Regular.ttf" "sha256-jMNkNTXt8DmqXZVECoVCc16Rl+T0uNkwPpgP779athY=")
    (googleFont "ofl" "dmserifdisplay" "DMSerifDisplay-Italic.ttf" "sha256-33TArDh7rq6w/k8jJOFmjmo+2MCc2Xlv4WLHF1PhnkU=")
    (googleFont "ofl" "instrumentserif" "InstrumentSerif-Regular.ttf" "sha256-SY79Rh9t38t6ERv5pWVwnSCF1IIB1QHq2WDZPoT/u4g=")
    (googleFont "ofl" "allura" "Allura-Regular.ttf" "sha256-nBQrLlFYMsDfxP+LjqGPQDFJQ7+Te3LisjxGYbrBTMY=")
    (googleFont "ofl" "chonburi" "Chonburi-Regular.ttf" "sha256-qg2sTfCK8QeFuh3BASFJIif45CiPCiPRHdHR9af26/o=")
    (googleFont "ofl" "instrumentserif" "InstrumentSerif-Italic.ttf" "sha256-CJObi99TSv7CSuDvXgP5SJQM2aj+COf+y60EDmIyc4U=")
    (googleFont "ofl" "abrilfatface" "AbrilFatface-Regular.ttf" "sha256-WXHUo3WKkiqf7cf2+4JaljQaLnGMRaSyyaa0F8jE2+k=")
  ];
in
  runCommand "lyric-fonts" {} ''
    mkdir -p $out/share/fonts/truetype
    ${lib.concatMapStrings (f: ''
        cp ${f} $out/share/fonts/truetype/${f.name}
      '')
      fonts}
  ''
