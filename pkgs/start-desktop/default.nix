# Desktop helpers are held until the lock has securely covered every output.
{
  writeShellApplication,
  awww,
  cliphist,
  coreutils,
  lock-session,
  networkmanagerapplet,
  wl-clipboard,
}:
writeShellApplication {
  name = "start-desktop";
  runtimeInputs = [lock-session awww cliphist coreutils networkmanagerapplet wl-clipboard];
  text = builtins.readFile ./start-desktop.sh;
}
