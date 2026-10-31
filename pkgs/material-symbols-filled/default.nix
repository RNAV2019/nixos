# Material Symbols Rounded as a static font, filled at weight 400: the shell's one icon set
# (home/quickshell/Commons/Icons.qml). Qt takes a variable font's axes but its FreeType engine
# draws the default instance anyway, so FILL and wght are baked in here rather than set per
# Text. Its own family name keeps it from shadowing nixpkgs' variable font.
{
  runCommand,
  python3,
  material-symbols,
}:
runCommand "material-symbols-rounded-filled-${material-symbols.version}" {
  nativeBuildInputs = [(python3.withPackages (ps: [ps.fonttools]))];
} ''
  mkdir -p $out/share/fonts/truetype
  python3 ${./instance.py} \
    "${material-symbols}/share/fonts/truetype/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" \
    $out/share/fonts/truetype/MaterialSymbolsRoundedFilled.ttf
''
