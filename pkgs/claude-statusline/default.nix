# Claude Code status line in the active theme's colours.
{
  writeShellApplication,
  git,
  jq,
}:
writeShellApplication {
  name = "claude-statusline";
  runtimeInputs = [git jq];
  text = builtins.readFile ./claude-statusline.sh;
}
