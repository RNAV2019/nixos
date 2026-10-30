# Packages built in this repo; see pkgs/default.nix.
{
  pkgs,
  repoDir,
  ...
}: {
  home.packages = with pkgs; [
    # nixpkgs is at 5.1 now; the old pin was dropped for binary-cache hits.
    ani-cli
    lock-session
    start-desktop
    gen-commit
    ical-agenda
    forward-dev
    t3code-nightly
    # Replaces the `rebuild` alias: nom, the diff, and progress on the island.
    (rebuild.override {inherit repoDir;})
    island-usb
  ];
}
