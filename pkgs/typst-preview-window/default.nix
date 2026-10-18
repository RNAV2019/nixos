# Helium window for the Helix :preview Steel command; helium comes from PATH.
{
  writeShellApplication,
  coreutils,
  util-linux,
}:
writeShellApplication {
  name = "typst-preview-window";
  runtimeInputs = [coreutils util-linux];
  text = builtins.readFile ./typst-preview-window.sh;
}
