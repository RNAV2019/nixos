# The launcher's emoji table, built from Unicode's emoji-test.txt and the CLDR English
# keywords so it follows nixpkgs rather than a vendored copy. Linked into
# ~/.local/share/quickshell by home/desktop.nix; Services/EmojiSearch.qml reads it.
{
  runCommand,
  python3,
  unicode-emoji,
  cldr-annotations,
}: let
  cldr = "${cldr-annotations}/share/unicode/cldr/common";
in
  runCommand "quickshell-emoji-${unicode-emoji.version}" {
    nativeBuildInputs = [python3];
  } ''
    mkdir -p $out/share/quickshell
    python3 ${./build.py} \
      ${unicode-emoji}/share/unicode/emoji/emoji-test.txt \
      ${cldr}/annotations/en.xml \
      ${cldr}/annotationsDerived/en.xml \
      $out/share/quickshell/emoji.tsv
  ''
