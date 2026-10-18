# Rate-limit percentages for the bar, via Claude Code's stored OAuth token.
# Expired tokens report `expired`; failed polls fall back to the cached reading.
{
  writeShellApplication,
  coreutils,
  curl,
  jq,
}:
writeShellApplication {
  name = "claude-usage";
  runtimeInputs = [curl jq coreutils];
  text = builtins.readFile ./claude-usage.sh;
}
