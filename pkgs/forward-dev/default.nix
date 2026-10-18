# Expose a local port at dev.ryannavsaria.co.uk through the Cloudflare tunnel.
{
  writeShellApplication,
  cloudflared,
}:
writeShellApplication {
  name = "forward-dev";
  runtimeInputs = [cloudflared];
  text = builtins.readFile ./forward-dev.sh;
}
