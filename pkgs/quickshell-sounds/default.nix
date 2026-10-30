# The shell's interface sounds, synthesised with sox so they are reproducible and nothing is
# downloaded. Linked into ~/.local/share/quickshell/sounds by home/desktop.nix;
# Services/Sounds.qml plays them. Every sound is a sine with a soft octave over it (or filtered
# noise for the shutter), faded in and out so none clicks, and levelled to one RMS so no sound is
# louder than its neighbours; see build.sh.
{
  runCommand,
  sox,
  gawk,
}:
runCommand "quickshell-sounds" {
  nativeBuildInputs = [sox gawk];
} ''
  mkdir -p $out/share/quickshell/sounds
  bash ${./build.sh} $out/share/quickshell/sounds
''
