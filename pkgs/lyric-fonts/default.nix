# The display faces the lyric stage sets words in (home/quickshell/Lyrics): each is one voice,
# and a style may change voice from word to word. All are single static fonts from Google
# Fonts, under the OFL (Permanent Marker: Apache 2.0). The families' names are listed in
# Theme.lyricFaces; a face that is not installed falls back to the shell's own.
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
    (googleFont "ofl" "instrumentserif" "InstrumentSerif-Italic.ttf" "sha256-CJObi99TSv7CSuDvXgP5SJQM2aj+COf+y60EDmIyc4U=")
    (googleFont "apache" "permanentmarker" "PermanentMarker-Regular.ttf" "sha256-KPgsinlDy46dWZ+FVNodT8ddvPabmIWtbAYR0gxpRsU=")
    (googleFont "ofl" "rubikmonoone" "RubikMonoOne-Regular.ttf" "sha256-siYktqNuVD6UIQbt/M0ZjFC1e2W5JL/gKm8KVplCnms=")
    (googleFont "ofl" "bungee" "Bungee-Regular.ttf" "sha256-xPU2HOEgrz5rkVbQvzefoZzaLqDNGKwB/ZlZbGv2bj8=")
    (googleFont "ofl" "pacifico" "Pacifico-Regular.ttf" "sha256-W2wNUzSnv3fepSuXXFoMQIh4wPcRXtW2+xUfY0t79wE=")
    (googleFont "ofl" "monoton" "Monoton-Regular.ttf" "sha256-lRxM6mX/7eeEp8lnL+7F0ymn4eEiFsQtU+zzbJDQTeo=")
    (googleFont "ofl" "spacemono" "SpaceMono-Bold.ttf" "sha256-QF5z1Br7flkG784gajJq9clW844lXzVCHCYOhh5ZnFk=")
    (googleFont "ofl" "abrilfatface" "AbrilFatface-Regular.ttf" "sha256-WXHUo3WKkiqf7cf2+4JaljQaLnGMRaSyyaa0F8jE2+k=")
    (googleFont "ofl" "shrikhand" "Shrikhand-Regular.ttf" "sha256-i6MvbWqW+428kvwaz7xNISPVNIBj2JssPdeE56/Lga8=")
    (googleFont "ofl" "alfaslabone" "AlfaSlabOne-Regular.ttf" "sha256-KGZK+mmKM5O9Winux1AjCgZFxTAdYiAOXy06An+yKZ0=")
    (googleFont "ofl" "pressstart2p" "PressStart2P-Regular.ttf" "sha256-A0x38fBeyJQh5KY/DjpMoez4UsxtK/YR8SbydXKOAX0=")
    (googleFont "ofl" "caveatbrush" "CaveatBrush-Regular.ttf" "sha256-5WW9e//Ylcpk+NHLd8gWubONnAECRjhqB8lkhZL28oI=")
    (googleFont "ofl" "bebasneue" "BebasNeue-Regular.ttf" "sha256-CORiOAUQLYGfWGAeRuNFZIhGB142OyzrIzE8LRyD7HM=")
  ];
in
  runCommand "lyric-fonts" {} ''
    mkdir -p $out/share/fonts/truetype
    ${lib.concatMapStrings (f: ''
        cp ${f} $out/share/fonts/truetype/${f.name}
      '')
      fonts}
  ''
